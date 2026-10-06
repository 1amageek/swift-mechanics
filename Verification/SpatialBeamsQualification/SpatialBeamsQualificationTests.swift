import Testing
#if canImport(SpatialBeamsQualificationSupport)
import SpatialBeamsQualificationSupport
#endif

@Suite(.timeLimit(.minutes(1)))
struct SpatialBeamsQualificationTests {
    @Test func axialAndTorsion() throws { try run(.axialAndTorsion) }
    @Test func bendingAndShear() throws { try run(.bendingAndShear) }
    @Test func massAndDamping() throws { try run(.massAndDamping) }
    @Test func frameFieldsAndPower() throws { try run(.frameFieldsAndPower) }
    @Test func originalRefusals() throws { try run(.originalRefusals) }
    @Test func resourcesAndCancellation() throws { try run(.resourcesAndCancellation) }
    private func run(_ selected: SpatialBeamsQualificationCase) throws {
        if #available(macOS 15.0, *) {
            let suite: any SpatialBeamsQualifying = SpatialBeamsQualificationCases()
            try suite.run(selected)
        } else {
            throw SpatialBeamsQualificationError.unsupportedNativePlatform
        }
    }
    @Test func actualTaskCancellationIsAwaited() async throws {
        if #available(macOS 15.0, *) {
            let entry = try SpatialBeamsQualificationCases().taskCancellationEntry()
            let task = Task { () throws -> Void in
                withUnsafeCurrentTask { $0?.cancel() }
                try entry()
            }
            try await task.value
        } else {
            throw SpatialBeamsQualificationError.unsupportedNativePlatform
        }
    }
}
