import SwiftMechanics

/// Owns one immutable actual endpoint while the caller carries only its reference across integration.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class PrescribedRootEndpointProbe: Sendable {
    let accepted: RuntimeAcceptedState

    @inline(never)
    init(session: PrescribedRootProbeContext.Session, equation: GeometricMechanismEquation,
         continuation: IntegrationContinuationProvider, time: Double) throws {
        let service: any ProjectedMechanismEvolving = ProjectedNonlinearMechanismEvolution()
        accepted = try service.advance(session, equations: equation, continuation: continuation, to: time).accepted
    }
}
