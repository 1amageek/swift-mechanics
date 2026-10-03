import MechanicsNumerics
public protocol TetrahedralMeshValidating: Sendable {
    func validate(_ mesh: TetrahedralMesh, admission: MeshAdmission, work: inout NumericalWork) throws(FlexibleError) -> ValidatedTetrahedralMesh
    func refine(_ mesh: ValidatedTetrahedralMesh, revision: UInt64, newNodeIdentifiers: [UInt64], newCellIdentifiers: [UInt64], admission: MeshAdmission, work: inout NumericalWork) throws(FlexibleError) -> ValidatedTetrahedralMesh
}
