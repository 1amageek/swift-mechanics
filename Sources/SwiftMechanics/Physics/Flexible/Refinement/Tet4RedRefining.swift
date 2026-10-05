public protocol Tet4RedRefining: Sendable {
    func layout(source: Tet4RefinementSource, policy: RefinementPolicy,
                work: inout NumericalWork) throws(RefinementError) -> Tet4RefinementLayout
    func refine(_ layout: Tet4RefinementLayout, meshRevision: UInt64, geometryRevision: UInt64,
                identifiers: RefinementIdentifierAllocation, diagonal: CentralOctahedronDiagonalPolicy,
                boundary: RefinementBoundaryMapping, loads: ConcentratedRefinementLoads, loadPolicy: RefinementLoadPolicy,
                policy: RefinementPolicy, admission: MeshAdmission,
                work: inout NumericalWork) throws(RefinementError) -> Tet4RefinementResult
}
