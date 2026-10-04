public struct MechanicalTangent: Sendable {
    public let tree: TreeTangent
    public let system: RigidDynamicsSystem
    public let massMatrix: [Double]
    public let inertialBias: [Double]
    public let totalForce: [Double]
    public let kineticEnergy: Double
    public let gravityPotential: Double
    public let actualLoadPower: Double
    public let virtualLoadPower: Double
    public let prescribedLoadPower: Double
    public let parameterIDs: [UInt64]
    public let parameterDimensions: [PhysicalDimension]
    internal let inertiaDirections: [BodyInertiaDirection]
}
