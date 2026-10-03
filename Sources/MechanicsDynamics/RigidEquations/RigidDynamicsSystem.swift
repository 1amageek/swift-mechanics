import MechanicsNumerics
import MechanicsLoads
public struct RigidDynamicsSystem: Sendable {
    public let input: RigidDynamicsInput
    public let velocityCount: Int
    /// Row-major M in the snapshot's generalized velocity basis.
    public let massMatrix: [Double]
    public let inertialBias: [Double]
    public let forces: ForceBudget
    public let gravityExplicitPotentialTimeDerivative: Double
    public let gravityPotential: Double
    public let knownLoadPotential: Double?
    public let knownDissipatedPower: Double?
    public let assemblyLoadWork: LoadWork
    public let assemblyWork: NumericalWork
    public let scalarStorage: Int
    internal let admission: DynamicsAdmission
    internal init(input: RigidDynamicsInput, massMatrix: [Double], inertialBias: [Double], forces: ForceBudget,
                  gravityPotential: Double, gravityExplicitPotentialTimeDerivative: Double, knownLoadPotential: Double?, knownDissipatedPower: Double?,
                  assemblyWork: NumericalWork, assemblyLoadWork: LoadWork, scalarStorage: Int, admission: DynamicsAdmission) {
        self.input = input; velocityCount = input.velocity.count; self.massMatrix = massMatrix; self.inertialBias = inertialBias
        self.forces = forces; self.gravityPotential = gravityPotential;
        self.gravityExplicitPotentialTimeDerivative = gravityExplicitPotentialTimeDerivative; self.knownLoadPotential = knownLoadPotential
        self.knownDissipatedPower = knownDissipatedPower; self.assemblyWork = assemblyWork; self.assemblyLoadWork = assemblyLoadWork
        self.scalarStorage = scalarStorage; self.admission = admission
    }
}
