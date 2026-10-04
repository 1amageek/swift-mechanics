import SwiftMechanics

@available(macOS 15, *)
public struct CADGearRuntimeRecipe: Sendable {
    public let descriptor: MechanicalDescriptor
    public let compilation: CompilationPolicy
    public let layout: ConstraintCoordinateLayout
    public let gears: CADGearPairRequest
    public let binding: CADGearBindingPolicy
    public let transmission: TransmissionPolicy
    public let equationIdentity: String
    public let drive: [Double]
    public let solve: MechanismSolvePolicy
    public let projection: NonlinearMechanismProjectionPolicy
    public let dynamics: DynamicsAdmission
    public let integration: ExplicitIntegrationPolicy
    public let validation: NumericalBudget
    public let maximumIdentityBytes: Int

    public init(descriptor: MechanicalDescriptor, compilation: CompilationPolicy,
                layout: ConstraintCoordinateLayout, gears: CADGearPairRequest,
                binding: CADGearBindingPolicy, transmission: TransmissionPolicy,
                equationIdentity: String, drive: [Double], solve: MechanismSolvePolicy,
                projection: NonlinearMechanismProjectionPolicy, dynamics: DynamicsAdmission,
                integration: ExplicitIntegrationPolicy, validation: NumericalBudget,
                maximumIdentityBytes: Int) throws(CADGearReinitializationError) {
        guard maximumIdentityBytes > 0, !equationIdentity.isEmpty,
              equationIdentity.utf8.count <= maximumIdentityBytes,
              drive.count == 2, drive.allSatisfy({ $0.isFinite }) else { throw .invalidInput }
        self.descriptor = descriptor; self.compilation = compilation; self.layout = layout
        self.gears = gears; self.binding = binding; self.transmission = transmission
        self.equationIdentity = equationIdentity; self.drive = drive; self.solve = solve
        self.projection = projection; self.dynamics = dynamics; self.integration = integration
        self.validation = validation; self.maximumIdentityBytes = maximumIdentityBytes
    }
}
