public struct ControlPolicy: Sendable {
    public let maximumMetadataBytes:Int,maximumGraphNodes:Int,maximumGraphEdges:Int,maximumPayloadBytes:Int
    public let maximumPositionMeters:Double,maximumRateMetersPerSecond:Double
    public let agreement:NumericalTolerance
    public let actuation:ActuationBudget
    public let numerical:NumericalBudget
    public let dynamics:DynamicsSolvePolicy
    public let admission:DynamicsAdmission
    public let inertia:InertiaValidationPolicy
    public let integration:ExplicitIntegrationPolicy
    public let runtimeCapacity:RuntimeCapacity
    public let continuation:RuntimeContinuationIdentity
    public let isCancelled:@Sendable () -> Bool
    public init(maximumMetadataBytes:Int,maximumGraphNodes:Int,maximumGraphEdges:Int,maximumPayloadBytes:Int,
                maximumPositionMeters:Double,maximumRateMetersPerSecond:Double,agreement:NumericalTolerance,
                actuation:ActuationBudget,numerical:NumericalBudget,dynamics:DynamicsSolvePolicy,admission:DynamicsAdmission,
                inertia:InertiaValidationPolicy,integration:ExplicitIntegrationPolicy,runtimeCapacity:RuntimeCapacity,
                continuation:RuntimeContinuationIdentity,isCancelled:@escaping @Sendable () -> Bool = {false}) throws(ControlFailure) {
        guard maximumMetadataBytes >= 0,maximumGraphNodes > 0,maximumGraphEdges >= 0,maximumPayloadBytes >= 0,
              maximumPositionMeters.isFinite,maximumPositionMeters > 0,maximumRateMetersPerSecond.isFinite,maximumRateMetersPerSecond > 0,
              dynamics.coordinateScales.count == 1,integration.method == .classicalRK4,numerical == integration.budget.supplier else { throw ControlFailure(.invalidInput,phase:"policy") }
        self.maximumMetadataBytes=maximumMetadataBytes;self.maximumGraphNodes=maximumGraphNodes;self.maximumGraphEdges=maximumGraphEdges;self.maximumPayloadBytes=maximumPayloadBytes
        self.maximumPositionMeters=maximumPositionMeters;self.maximumRateMetersPerSecond=maximumRateMetersPerSecond;self.agreement=agreement
        self.actuation=actuation;self.numerical=numerical;self.dynamics=dynamics;self.admission=admission;self.inertia=inertia
        self.integration=integration;self.runtimeCapacity=runtimeCapacity;self.continuation=continuation;self.isCancelled=isCancelled
    }
}
