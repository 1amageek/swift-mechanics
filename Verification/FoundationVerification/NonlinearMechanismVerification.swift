import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func verifyNonlinearMechanisms() throws {
        let model = try MechanismProbeContext.model(q: [1, 0], v: [0, 1], acceleration: [-1, 0])
        let equation = try NonlinearMechanismProbeContext.equation(model)
        let (session, continuation) = try NonlinearMechanismProbeContext.session(model, equation: equation)
        defer { _ = session.shutdown() }
        let prefix = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        let evolved = try evolveNonlinear(session, equation: equation, continuation: continuation)
        try checkNonlinear(evolved.accepted)
        _ = try session.restart(prefix, codec: NativeRuntimeCheckpointCodec())
        let replay = try evolveNonlinear(session, equation: equation, continuation: continuation)
        try require(replay.accepted == evolved.accepted && session.snapshot() == replay.accepted)
        print("Nonlinear mechanism runtime verification passed: original q/v/a constraints, physical torque balance and replay.")
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func evolveNonlinear(_ session: NonlinearMechanismProbeContext.Session, equation: NonlinearMechanismEquation,
                                        continuation: IntegrationContinuationProvider) throws -> NonlinearMechanismAdvanceResult {
        let service: any NonlinearMechanismEvolving = ProjectedNonlinearMechanismEvolution()
        return try service.advance(session, equations: equation, continuation: continuation, to: 0.1)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkNonlinear(_ accepted: RuntimeAcceptedState) throws {
        let state = accepted.checkpoint.physical, q = state.q, v = state.v, a = state.acceleration
        try require(state.time == 0.1 && abs(q[0] * q[0] + q[1] * q[1] - 1) < 1e-7)
        try require(abs(q[0] * v[0] + q[1] * v[1]) < 1e-7)
        try require(abs(q[0] * a[0] + q[1] * a[1] + v[0] * v[0] + v[1] * v[1]) < 1e-7)
        try require(abs(2 * a[0] * q[1] - 4 * a[1] * q[0]) < 1e-7)
        try require(abs(v[0] * v[0] + 2 * v[1] * v[1] - 2) < 1e-6)
    }
}
