/// Existential projected evolution for both coordinate and geometric facade contracts.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol ProjectedMechanismEvolving: NonlinearMechanismEvolving {
    func advance(_ session:any RuntimeSessionOperating,equations:any ProjectedMechanismEquations,
                 continuation:IntegrationContinuationProvider,to time:Double) throws(NonlinearMechanismFailure) -> NonlinearMechanismAdvanceResult
}
