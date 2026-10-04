import SwiftMechanics
import Testing
#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("No admitted scalar mathematics platform module is available.")
#endif

struct PlanarRuntimeReplayTests {
    @Test func actualPressureAcceptRejectCheckpointAndFreshOwnerReplay() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime availability missing."); return }
        let fixture = try PlanarRuntimeFixture(); defer { _ = fixture.session.shutdown() }
        let initial = fixture.session.snapshot()
        let rejected = try fixture.advance(decision: .reject)
        #expect(rejected.decision == .reject && rejected.accepted == initial && fixture.session.snapshot() == initial)
        for _ in 0..<3 { _ = try fixture.advance() }
        let state = try fixture.accepted(), prefix = fixture.session.snapshot()
        #expect(state.sequence == 3 && state.time == prefix.physical.state.time)
        #expect(prefix.checkpoint.random.draws == 3 && prefix.checkpoint.acceptedSteps == 3)
        let original = try PlanarRuntimeFixtures.state(fixture.grid)
        #expect(state.u != original.u)
        #expect(state.pressure.contains { abs($0) > 1e-6 })
        var oldEnergy = 0.0, newEnergy = 0.0
        for k in 0..<fixture.grid.count {
            oldEnergy += 0.5*fixture.grid.cellMass*(original.u[k]*original.u[k]+original.v[k]*original.v[k])
            newEnergy += 0.5*fixture.grid.cellMass*(state.u[k]*state.u[k]+state.v[k]*state.v[k])
        }
        #expect(newEnergy < oldEnergy)
        for k in 0..<fixture.grid.count { #expect(abs(PlanarRuntimeFixtures.divergence(state, k: k)) < 1e-9) }
        let global: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        let checkpoint = try fixture.session.checkpoint(codec: global)
        let uninterrupted = try fixture.advance(), after = try fixture.accepted()
        _ = try fixture.session.restart(checkpoint, codec: global)
        #expect(fixture.session.snapshot() == prefix)
        let replay = try fixture.advance()
        #expect(try fixture.accepted() == after && replay.accepted == uninterrupted.accepted)
        let fresh = try PlanarRuntimeFixture(); defer { _ = fresh.session.shutdown() }
        _ = try fresh.session.restart(checkpoint, codec: global)
        #expect(fresh.session.snapshot() == prefix)
        let restored = try fresh.advance()
        #expect(restored.accepted == uninterrupted.accepted)
    }
    @Test func actualRuntimeShearMatchesIndependentDiscreteAmplification() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime availability missing."); return }
        let fixture = try PlanarRuntimeFixture(shear: true); defer { _ = fixture.session.shutdown() }
        let old = try fixture.accepted(), dt = 0.01, g = fixture.grid
        _ = try fixture.advance(duration: dt)
        let new = try fixture.accepted()
        let lambda = 4*g.nu*sin(PlanarRuntimeFixtures.pi/Double(g.ny))*sin(PlanarRuntimeFixtures.pi/Double(g.ny))/(g.dy*g.dy)
        for k in 0..<g.count {
            #expect(abs(new.u[k]-(1-lambda*dt)*old.u[k]) < 1e-10)
            #expect(abs(new.v[k]) < 1e-10 && abs(new.pressure[k]) < 1e-10)
        }
        #expect(new.grid.totalMass == old.grid.totalMass && new.sequence == 1)
    }
    @Test func wholeCheckpointAdmissionRejectsForgedTimeAndSequenceBeforeRestartPublication() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime availability missing."); return }
        let fixture = try PlanarRuntimeFixture(); defer { _ = fixture.session.shutdown() }
        _ = try fixture.advance()
        let prefix = fixture.session.snapshot(), old = prefix.checkpoint, record = old.contributors[0]
        let offset = PlanarRuntimeFixtures.dynamicOffset(fixture.codec)
        let changed = [try PlanarRuntimeFixtures.changed(record, offset: offset, value: Double(2).bitPattern),
                       try PlanarRuntimeFixtures.changed(record, offset: offset+8, value: UInt64(7))]
        for contributor in changed {
            var bytes = try PlanarRuntimeFixtures.bytes()
            _ = try fixture.codec.decode(contributor, work: &bytes) // Structurally and locally physically valid.
            let forged = try RuntimeCheckpoint(model: old.model, continuation: old.continuation, physical: old.physical,
                contributors: [contributor], random: old.random, acceptedSteps: old.acceptedSteps)
            let wire = try NativeRuntimeCheckpointCodec().encode(forged, capacity: fixture.session.configuration.capacity)
            do throws(RuntimeFailure) {
                _ = try fixture.session.restart(wire, codec: NativeRuntimeCheckpointCodec())
                Issue.record("Incoherent restored field unexpectedly published.")
            } catch { #expect(error.code == .invalidState && error.lastAccepted == prefix) }
            #expect(fixture.session.snapshot() == prefix)
        }
        #expect(throws: RuntimeFailure.self) { _ = try PlanarRuntimeFixture(time: 1) }
        #expect(throws: RuntimeFailure.self) { _ = try PlanarRuntimeFixture(sequence: 1) }
    }
}
