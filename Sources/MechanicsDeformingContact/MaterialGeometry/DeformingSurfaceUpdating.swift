import MechanicsModel
import MechanicsFlexible
import MechanicsNumerics
public protocol DeformingSurfaceUpdating: Sendable {
    func extract(_ mesh: ValidatedTetrahedralMesh, body: ModelReference, policy: DeformingContactPolicy, work: inout NumericalWork) throws(DeformingContactError) -> MaterialSurface
    func update(_ surface: MaterialSurface, state: NodalState, geometryRevision: UInt64, time: Double,
                previous: DeformingSurfaceSnapshot?, policy: DeformingContactPolicy, work: inout NumericalWork) throws(DeformingContactError) -> DeformingSurfaceSnapshot
    func point(_ material: SurfaceMaterialPoint, in snapshot: DeformingSurfaceSnapshot, policy: DeformingContactPolicy, work: inout NumericalWork) throws(DeformingContactError) -> SurfacePointKinematics
}
