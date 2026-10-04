/// Producer-admitted equation with complete original physical source and immutable evidence.
public final class PhysicalRigidDynamicsSystem: Sendable {
    public let input: PhysicalRigidDynamicsInput
    public let velocityCount: Int
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
    public let admission: DynamicsAdmission
    private let originalSpatial: RigidDynamicsSystem?
    /// Retains an actually admitted legacy system; no planar source can use this bridge.
    public init(spatial system: RigidDynamicsSystem) {
        input = PhysicalRigidDynamicsInput(spatial: system.input); velocityCount = system.velocityCount
        massMatrix = system.massMatrix; inertialBias = system.inertialBias; forces = system.forces
        gravityExplicitPotentialTimeDerivative = system.gravityExplicitPotentialTimeDerivative
        gravityPotential = system.gravityPotential; knownLoadPotential = system.knownLoadPotential
        knownDissipatedPower = system.knownDissipatedPower; assemblyLoadWork = system.assemblyLoadWork
        assemblyWork = system.assemblyWork; scalarStorage = system.scalarStorage
        admission = system.admission; originalSpatial = system
    }
    internal init(input: PhysicalRigidDynamicsInput, massMatrix: [Double], inertialBias: [Double], forces: ForceBudget,
                  gravityPotential: Double, gravityExplicitPotentialTimeDerivative: Double, knownLoadPotential: Double?, knownDissipatedPower: Double?,
                  assemblyWork: NumericalWork, assemblyLoadWork: LoadWork, scalarStorage: Int, admission: DynamicsAdmission) {
        self.input = input; velocityCount = input.velocity.count; self.massMatrix = massMatrix; self.inertialBias = inertialBias
        self.forces = forces; self.gravityPotential = gravityPotential
        self.gravityExplicitPotentialTimeDerivative = gravityExplicitPotentialTimeDerivative
        self.knownLoadPotential = knownLoadPotential; self.knownDissipatedPower = knownDissipatedPower
        self.assemblyWork = assemblyWork; self.assemblyLoadWork = assemblyLoadWork; self.scalarStorage = scalarStorage
        self.admission = admission; originalSpatial = nil
    }
    @inline(never)
    public func spatialSystem() throws(DynamicsError) -> RigidDynamicsSystem {
        if let originalSpatial { return originalSpatial }
        guard case .spatial(let source) = input.source else { throw .unsupportedDomain }
        return RigidDynamicsSystem(input: source, massMatrix: massMatrix, inertialBias: inertialBias, forces: forces,
            gravityPotential: gravityPotential, gravityExplicitPotentialTimeDerivative: gravityExplicitPotentialTimeDerivative,
            knownLoadPotential: knownLoadPotential, knownDissipatedPower: knownDissipatedPower,
            assemblyWork: assemblyWork, assemblyLoadWork: assemblyLoadWork, scalarStorage: scalarStorage, admission: admission)
    }
}
