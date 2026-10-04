@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class NonlinearEvolutionRunContext: Sendable {
    let session:any RuntimeSessionOperating
    let equations:any ProjectedMechanismEquations
    let continuation:IntegrationContinuationProvider
    let target:Double
    init(session:any RuntimeSessionOperating,equations:any ProjectedMechanismEquations,continuation:IntegrationContinuationProvider,target:Double) {
        self.session=session;self.equations=equations;self.continuation=continuation;self.target=target
    }
}
