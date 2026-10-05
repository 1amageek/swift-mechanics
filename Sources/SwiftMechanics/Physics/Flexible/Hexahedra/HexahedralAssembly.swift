public struct HexahedralAssembly: Sendable {
    /// Retains exact reference nodes, frame, mesh/cell/material revisions, sources and assignments.
    public let reference: ValidatedHexahedralMesh
    /// Retains the exact current positions/velocities and their declared revision/provenance.
    public let state: HexahedralNodalState
    public let nodeIdentifiers: [UInt64]
    public let coordinateCount: Int
    /// Row-major physical matrices; all coordinates are node-major XYZ translations in m.
    public let internalForce: [Double]
    public let tangent: [Double]
    public let mass: [Double]
    public let damping: [Double]
    public let dampingForce: [Double]
    public let storedEnergy: Double
    public let dissipatedPower: Double
    public let totalReferenceMass: Double
    public let totalReferenceVolume: Double
    public let massForm: FlexibleMassForm
    public let numericalWork: NumericalWork
    public let constitutiveWork: HexahedralConstitutiveWork

    public var frame: EntityID { reference.mesh.frame }
    public var meshIdentifier: UInt64 { reference.mesh.identifier }
    public var meshRevision: UInt64 { reference.mesh.revision }
    public var source: SourceProvenance { reference.mesh.source }
    public var forceDimension: PhysicalDimension { .force }
    public var tangentDimension: PhysicalDimension { PhysicalDimension(mass: 1, time: -2) }
    public var massDimension: PhysicalDimension { .mass }
    public var dampingDimension: PhysicalDimension { PhysicalDimension(mass: 1, time: -1) }
    public var energyDimension: PhysicalDimension { .energy }
    public var powerDimension: PhysicalDimension { PhysicalDimension(length: 2, mass: 1, time: -3) }
}
