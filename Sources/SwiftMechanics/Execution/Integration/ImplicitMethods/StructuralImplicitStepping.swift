@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol StructuralImplicitStepping: Sendable {
    /// Returns an owned endpoint proposal; the caller owns physical initial equilibrium and publication.
    func step(_ input: StructuralIntegrationState, equations: any StructuralImplicitEquations, to time: Double,
              policy: StructuralImplicitPolicy) throws(StructuralImplicitFailure) -> StructuralImplicitEndpoint
}
