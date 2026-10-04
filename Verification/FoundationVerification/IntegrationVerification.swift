import SwiftMechanics

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func verifyIntegration() throws {
        for method in [ExplicitIntegrationMethod.classicalRK4, .heunEuler] {
            let context = try IntegrationProbeContext(method: method)
            defer { _ = context.first.shutdown(); _ = context.second.shutdown() }
            try verifyIntegrationFirstStep(context, method: method)
            try verifyIntegrationContinuation(context)
            try verifyIntegrationFailure(context)
        }
    }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyIntegrationFirstStep(_ context: IntegrationProbeContext, method: ExplicitIntegrationMethod) throws {
        let service: any ExplicitIntegrating = ReferenceExplicitIntegrator()
        let step = try service.step(context.first, model: context.fixture.model, equations: context.equation, continuation: context.continuation)
        try require(step.acceptedSteps == 1 && step.accepted.checkpoint.random.draws == 1)
        if method == .heunEuler { try require(step.rejectedTrials > 0) }
        let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        _ = try context.second.restart(context.first.checkpoint(codec: codec), codec: codec)
    }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyIntegrationContinuation(_ context: IntegrationProbeContext) throws {
        let service: any ExplicitIntegrating = ReferenceExplicitIntegrator()
        let result = try service.advance(context.first, model: context.fixture.model, equations: context.equation, continuation: context.continuation, to: 0.5)
        _ = try service.advance(context.second, model: context.fixture.model, equations: context.equation, continuation: context.continuation, to: 0.5)
        try require(result.reachedRequestedTime && result.accepted.checkpoint.physical.time == 0.5)
        try require(abs(result.accepted.checkpoint.physical.q[0] - 1.25) < 1e-10 && abs(result.accepted.checkpoint.physical.v[0] - 3) < 1e-10)
        try require(context.first.snapshot() == context.second.snapshot() && context.first.snapshot().checkpoint.random.draws == context.first.snapshot().checkpoint.acceptedSteps)
        let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        try require(try context.first.checkpoint(codec: codec) == context.second.checkpoint(codec: codec))
    }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyIntegrationFailure(_ context: IntegrationProbeContext) throws {
        let service: any ExplicitIntegrating = ReferenceExplicitIntegrator()
        let prefix = context.first.snapshot()
        let malformed = try IntegrationProbeEquation(model: context.fixture.model, malformed: true)
        var malformedRejected = false
        do throws(IntegrationFailure) {
            _ = try service.advance(context.first, model: context.fixture.model, equations: malformed, continuation: context.continuation, to: 0.6)
        } catch { try require(error.cause.code == .invalidState && error.lastAccepted == prefix); malformedRejected = true }
        try require(malformedRejected && context.first.snapshot() == prefix)
        let nested = try IntegrationProbeEquation(model: context.fixture.model, nestedFailure: true)
        var nestedRejected = false
        do throws(IntegrationFailure) {
            _ = try service.advance(context.first, model: context.fixture.model, equations: nested, continuation: context.continuation, to: 0.6)
        } catch {
            try require(error.cause.code == .invalidState && error.cause.failedSupplierWorkUnavailable)
            try require(error.work.failedSupplierWorkUnavailable && error.work.supplierArithmeticCharged == 3 && error.work.derivativeCalls == 1)
            try require(error.lastAccepted == prefix); nestedRejected = true
        }
        try require(nestedRejected && context.first.snapshot() == prefix)
    }
}
