import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func verifyGeometricEvolution() throws {
        let fixture = try FourBarProbeModel(), equation = try GeometricEvolutionProbeContext.equation(fixture)
        let (session, provider) = try GeometricEvolutionProbeContext.session(fixture, equation: equation)
        defer { _ = session.shutdown() }
        let initial = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        let evolved = try advanceGeometricEvolution(session, equation: equation, provider: provider)
        try checkGeometricEvolution(fixture, result: evolved)
        let saved = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        _ = try session.restart(initial, codec: NativeRuntimeCheckpointCodec())
        let replay = try advanceGeometricEvolution(session, equation: equation, provider: provider)
        try require(replay.accepted == evolved.accepted && session.snapshot() == evolved.accepted)
        try require(try session.checkpoint(codec: NativeRuntimeCheckpointCodec()) == saved)
        print("AF22 geometric evolution: torque-driven four-bar, original q/v/a, rod energy and exact replay passed")
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func advanceGeometricEvolution(_ session: GeometricEvolutionProbeContext.Session,
        equation: GeometricMechanismEquation, provider: IntegrationContinuationProvider) throws(NonlinearMechanismFailure) -> NonlinearMechanismAdvanceResult {
        let service: any ProjectedMechanismEvolving = ProjectedNonlinearMechanismEvolution()
        do throws(NonlinearMechanismFailure) {
            return try service.advance(session, equations: equation, continuation: provider, to: 0.1)
        } catch {
            print("AF22 geometric evolution failure: " + error.cause.message)
            throw error
        }
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkGeometricEvolution(_ fixture: FourBarProbeModel, result: NonlinearMechanismAdvanceResult) throws {
        let state = result.accepted.checkpoint.physical
        try require(state.time == 0.1)
        for residual in fixture.originalClosure(q: state.q) { try require(abs(residual) < 1e-8) }
        for residual in fixture.originalVelocity(q: state.q, v: state.v) { try require(abs(residual) < 1e-8) }
        for residual in fixture.originalAcceleration(q: state.q, v: state.v, acceleration: state.acceleration) {
            try require(abs(residual) < 1e-8)
        }
        let kinetic = fixture.originalKineticEnergy(q: state.q, v: state.v)
        let inputWork = state.q[fixture.crankIndex] - fixture.model.descriptor.initialState.q[fixture.crankIndex]
        try require(inputWork > 0 && kinetic > 0 && abs(kinetic - inputWork) < 1e-7)
    }
}
