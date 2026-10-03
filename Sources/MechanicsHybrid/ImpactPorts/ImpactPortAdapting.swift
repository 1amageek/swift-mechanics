import MechanicsDynamics
import MechanicsLoads
import MechanicsNumerics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol ImpactPortAdapting: Sendable {
    func prepare(_ input: HardImpactInput, policy: HybridPolicy, admission: DynamicsAdmission,
                 loadWork: inout LoadWork, work: inout NumericalWork, cancellation: HybridCancellation) throws(HybridError) -> PreparedImpact
}
