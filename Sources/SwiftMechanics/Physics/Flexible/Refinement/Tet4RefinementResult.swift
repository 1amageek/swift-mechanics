public final class Tet4RefinementResult: Sendable {
    public let layout: Tet4RefinementLayout
    public let refined: Tet4RefinementSource
    public let identifiers: RefinementIdentifierAllocation
    public let diagonalPolicy: CentralOctahedronDiagonalPolicy
    public let boundaryAssignments: RefinementBoundaryAssignments
    public let prolongation: [RefinementProlongationRow]
    public let cells: [RefinementCellMapping], faces: [RefinementFaceSubdivision]
    public let loads: [Vector3], loadPolicy: RefinementLoadPolicy
    public let originalLoads: ConcentratedRefinementLoads
    public let dualResidual: Double, forceResidual: Double, momentResidual: Double, powerResidual: Double
    public let momentReferencePosition: Vector3
    public let policy: RefinementPolicy, meshAdmission: MeshAdmission, numericalWork: NumericalWork
    internal init(layout: Tet4RefinementLayout, refined: Tet4RefinementSource, identifiers: RefinementIdentifierAllocation,
                  diagonal: CentralOctahedronDiagonalPolicy, boundary: RefinementBoundaryAssignments,
                  prolongation: [RefinementProlongationRow], cells: [RefinementCellMapping], faces: [RefinementFaceSubdivision],
                  loads: [Vector3], originalLoads: ConcentratedRefinementLoads,
                  dual: Double, force: Double, moment: Double, power: Double,
                  policy: RefinementPolicy, admission: MeshAdmission, work: NumericalWork) {
        self.layout = layout; self.refined = refined; self.identifiers = identifiers; self.diagonalPolicy = diagonal
        self.boundaryAssignments = boundary; self.prolongation = prolongation; self.cells = cells; self.faces = faces
        self.loads = loads; self.loadPolicy = .retainConcentratedOriginalNodes
        self.originalLoads = originalLoads
        self.dualResidual = dual; self.forceResidual = force; self.momentResidual = moment; self.powerResidual = power
        self.momentReferencePosition = layout.source.state.positions[0]
        self.policy = policy; self.meshAdmission = admission; self.numericalWork = work
    }
}
