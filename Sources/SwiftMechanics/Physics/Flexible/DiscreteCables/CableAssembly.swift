public struct CableAssembly: Sendable {
    public let cable: DiscreteCable
    public let derivativeOrder: CableDerivativeOrder
    public let physicalInternalForce: [Vector3]
    public let stiffnessBlocks: [CableStiffnessBlock]?
    public let lumpedNodeMass: [Double]
    public let dampingDiagonal: [Double]
    public let physicalDampingForce: [Vector3]
    public let storedEnergy: Double
    public let dissipatedPower: Double
    public let totalReferenceMass: Double
    public let numericalWork: NumericalWork
}
