@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol ConstrainedImpactPreparing: Sendable {
    func prepare(input: HardImpactInput, constraints: QuadraticConstraintSystem, policy: ConstrainedImpactPolicy,
                 admission: DynamicsAdmission, loadWork: inout LoadWork, work: inout NumericalWork,
                 cancellation: HybridCancellation) throws(ConstrainedImpactError) -> PreparedConstrainedImpact
}
