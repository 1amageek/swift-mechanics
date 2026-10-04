import SwiftMechanics
import Testing

struct PlanarContinuationCodecTests {
    @Test func requiredCodecRoundTripsAllPhysicalFields() throws {
        let model = try PlanarRuntimeFixtures.model(), g = try PlanarRuntimeFixtures.grid()
        let codec = try PlanarRuntimeFixtures.codec(grid: g, model: model.stamp)
        let operation: any PlanarContinuationCoding = codec
        let velocity = try PlanarRuntimeFixtures.state(g)
        var pressure = [Double](repeating: 0, count: g.count)
        for k in 0..<g.count { pressure[k] = Double(k)*0.125 }
        let initial = try PlanarState(grid: g, time: 0.25, sequence: 7, u: velocity.u, v: velocity.v, pressure: pressure,
                                      source: PlanarSource(accelerationX: 0.3, accelerationY: -0.2))
        var bytes = try PlanarRuntimeFixtures.bytes()
        let record = try operation.encode(initial, work: &bytes)
        #expect(record.bytes.count == operation.encodedSize)
        #expect(try operation.decode(record, work: &bytes) == initial)
        #expect(bytes.workUnits > record.bytes.count && bytes.peakStorageBytes == codec.requiredScratchBytes)
    }
    @Test func untrustedLengthIdentityAndContextNeverBecomeSuccess() throws {
        let model = try PlanarRuntimeFixtures.model(), g = try PlanarRuntimeFixtures.grid()
        let codec = try PlanarRuntimeFixtures.codec(grid: g, model: model.stamp)
        var bytes = try PlanarRuntimeFixtures.bytes()
        let record = try codec.encode(PlanarRuntimeFixtures.state(g), work: &bytes)
        let short = try RuntimeContributorState(id: record.id, category: record.category, version: record.version, bytes: Array(record.bytes.dropLast()))
        failure(.malformedPayload) { () throws(PlanarContinuationError) in _ = try codec.decode(short, work: &bytes) }
        let oversized = try RuntimeContributorState(id: record.id, category: record.category, version: record.version, bytes: record.bytes+[0])
        failure(.capacity) { () throws(PlanarContinuationError) in _ = try codec.decode(oversized, work: &bytes) }
        var changed = record.bytes; changed[0] ^= 1
        let invalid = try RuntimeContributorState(id: record.id, category: record.category, version: record.version, bytes: changed)
        failure(.staleBinding) { () throws(PlanarContinuationError) in _ = try codec.decode(invalid, work: &bytes) }
        let other = try PlanarRuntimeFixtures.codec(grid: PlanarRuntimeFixtures.grid(viscosity: 0.2), model: model.stamp)
        failure(.staleBinding) { () throws(PlanarContinuationError) in _ = try other.decode(record, work: &bytes) }
        let id = try RuntimeContributorState(id: "another-fluid", category: .integrator, version: 1, bytes: record.bytes)
        failure(.staleBinding) { () throws(PlanarContinuationError) in _ = try codec.decode(id, work: &bytes) }
        let longID = try RuntimeContributorState(id: String(repeating: "x", count: 2048), category: .integrator, version: 1, bytes: record.bytes)
        failure(.capacity) { () throws(PlanarContinuationError) in _ = try codec.decode(longID, work: &bytes) }
        let version = try RuntimeContributorState(id: record.id, category: record.category, version: 2, bytes: record.bytes)
        failure(.staleBinding) { () throws(PlanarContinuationError) in _ = try codec.decode(version, work: &bytes) }
    }
    @Test func reconstructedGaugeFiniteAndOriginalDivergenceAreAuthority() throws {
        let model = try PlanarRuntimeFixtures.model(), g = try PlanarRuntimeFixtures.grid()
        let codec = try PlanarRuntimeFixtures.codec(grid: g, model: model.stamp)
        var bytes = try PlanarRuntimeFixtures.bytes()
        let record = try codec.encode(PlanarRuntimeFixtures.state(g), work: &bytes)
        let offset = PlanarRuntimeFixtures.dynamicOffset(codec)
        let nan = try PlanarRuntimeFixtures.changed(record, offset: offset+32, value: Double.nan.bitPattern)
        failure(.physical(.nonfinite)) { () throws(PlanarContinuationError) in _ = try codec.decode(nan, work: &bytes) }
        let gauge = try PlanarRuntimeFixtures.changed(record, offset: offset+32+16*g.count, value: Double(1).bitPattern)
        failure(.physical(.invalidInput)) { () throws(PlanarContinuationError) in _ = try codec.decode(gauge, work: &bytes) }
        let divergence = try PlanarRuntimeFixtures.changed(record, offset: offset+32, value: Double(0.1).bitPattern)
        failure(.physical(.originalResidual)) { () throws(PlanarContinuationError) in _ = try codec.decode(divergence, work: &bytes) }
        let source = try PlanarRuntimeFixtures.changed(record, offset: offset+16, value: Double(11).bitPattern)
        failure(.physical(.domain)) { () throws(PlanarContinuationError) in _ = try codec.decode(source, work: &bytes) }
        let negativeTime = try PlanarRuntimeFixtures.changed(record, offset: offset, value: Double(-1).bitPattern)
        failure(.physical(.invalidInput)) { () throws(PlanarContinuationError) in _ = try codec.decode(negativeTime, work: &bytes) }
    }
    @Test func distinctStorageWorkAndCancellationBudgetsAreEnforced() throws {
        let model = try PlanarRuntimeFixtures.model(), g = try PlanarRuntimeFixtures.grid()
        let codec = try PlanarRuntimeFixtures.codec(grid: g, model: model.stamp)
        var bytes = try PlanarRuntimeFixtures.bytes()
        let record = try codec.encode(PlanarRuntimeFixtures.state(g), work: &bytes)
        var storage = try PlanarRuntimeFixtures.bytes(storage: codec.requiredScratchBytes-1)
        failure(.capacity) { () throws(PlanarContinuationError) in _ = try codec.decode(record, work: &storage) }
        var units = try PlanarRuntimeFixtures.bytes(units: 0)
        failure(.capacity) { () throws(PlanarContinuationError) in _ = try codec.decode(record, work: &units) }
        var cancel = try PlanarRuntimeFixtures.bytes(cancel: { true })
        failure(.cancelled) { () throws(PlanarContinuationError) in _ = try codec.decode(record, work: &cancel) }
        #expect(throws: PlanarContinuationError.self) {
            _ = try FixedPlanarContinuationCodec(grid: g, model: model.stamp, contributorID: "planar-fluid", maximumBytes: 8, divergenceTolerance: 1e-9)
        }
    }
    private func failure(_ expected: PlanarContinuationError, _ body: () throws(PlanarContinuationError) -> Void) {
        do throws(PlanarContinuationError) { try body(); Issue.record("Expected planar continuation failure.") }
        catch { #expect(error == expected) }
    }
}
