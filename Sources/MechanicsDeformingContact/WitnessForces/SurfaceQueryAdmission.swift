import MechanicsFlexible
import MechanicsModel
import MechanicsCollision
import MechanicsNumerics
internal enum SurfaceQueryAdmission {
    static func snapshot(_ s: DeformingSurfaceSnapshot, policy p: DeformingContactPolicy, work: inout NumericalWork) throws(DeformingContactError) {
        try SurfaceArithmetic.check(p)
        guard s.surface.mesh.mesh.nodes.count <= p.maximumNodes, s.surface.mesh.mesh.cells.count <= p.maximumCells,
              s.surface.triangles.count <= p.maximumFaces, s.state.positions.count <= p.maximumNodes,
              s.state.velocities.count <= p.maximumNodes else { throw .capacityExceeded }
        try SurfaceArithmetic.text(s.surface.body.id.key,p,&work); try SurfaceArithmetic.text(s.surface.mesh.mesh.frame.key,p,&work)
        try SurfaceArithmetic.text(s.state.frame.key,p,&work)
        let traversal=try SurfaceArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(32,s.surface.triangles.count) }
        try SurfaceArithmetic.charge(traversal,p,&work)
    }
    static func geometry(_ g: CollisionGeometryIdentity, policy p: DeformingContactPolicy, work: inout NumericalWork) throws(DeformingContactError) {
        try SurfaceArithmetic.text(g.bodyID.key,p,&work); try SurfaceArithmetic.text(g.frameID.key,p,&work); try SurfaceArithmetic.text(g.colliderID.key,p,&work)
        try SurfaceArithmetic.text(g.representation.assetKey,p,&work); try SurfaceArithmetic.text(g.representation.provenance.source,p,&work)
    }
}
