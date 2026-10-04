@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol NonlinearMechanismEvolving: Sendable {
    func advance(_ session: any RuntimeSessionOperating, equations: NonlinearMechanismEquation,
                 continuation: IntegrationContinuationProvider, to time: Double) throws(NonlinearMechanismFailure) -> NonlinearMechanismAdvanceResult
}
