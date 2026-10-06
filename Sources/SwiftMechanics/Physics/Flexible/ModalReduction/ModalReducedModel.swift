public struct ModalReducedModel: Sendable {
    public let pencil: StructuralPencil
    public let tetrahedra: ValidatedTetrahedralMesh?
    public let maps: ModalReductionMaps
    public let envelope: ModalReductionEnvelope
    public let policy: ModalReductionPolicy
    public let fullCoordinateCount: Int
    public let retainedModes: [Int]
    public let truncatedModes: [Int]
    public let eigenvalues: [Double]
    /// Physical source-coordinate displacement per dimensionless modal coordinate.
    public let basis: [Double]
    public let mass: [Double]
    public let stiffness: [Double]
    public let damping: [Double]
    public let reducedInputMap: [Double]
    public let reducedInterfaceMap: [Double]
    public let maximumMassGramError: Double
    public let maximumRetainedEigenResidual: Double
    public var count: Int { retainedModes.count }
}
