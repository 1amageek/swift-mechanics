import Testing
import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsFlexible
import MechanicsDeformingContact
@Suite struct MaterialGeometryTests {
    @Test func orientedBoundaryAndInteriorCancellation() throws {
        let mesh=try DeformingFixtures.mesh(points:[.zero,.unitX,.unitY,.unitZ,Vector3(0,0,-1)],cells:[[0,1,2,3],[0,2,1,4]])
        let surface=try DeformingFixtures.surface(mesh)
        #expect(surface.triangles.count == 6)
        for face in surface.triangles {
            let cell=mesh.mesh.cells.first { $0.identifier == face.feature.cell }!
            let a=mesh.mesh.nodes[face.nodes[0]].referencePosition, b=mesh.mesh.nodes[face.nodes[1]].referencePosition, c=mesh.mesh.nodes[face.nodes[2]].referencePosition
            let inside=mesh.mesh.nodes[cell.nodes[face.feature.oppositeNode]].referencePosition
            #expect(try b.subtracting(a).cross(c.subtracting(a)).dot(inside.subtracting(a)) < 0)
        }
        #expect(!surface.triangles.contains { Set($0.nodes) == Set([0,1,2]) })
    }
    @Test func actualAffineMaterialCoordinatesAndEpoch() throws {
        let s=try DeformingFixtures.surface(DeformingFixtures.mesh()), before=try DeformingFixtures.snapshot(s)
        let f=try Matrix3(2,0,0,0,3,0,0,0,4), translation=try Vector3(1,-1,2)
        let positions=try before.state.positions.map { try f.applying(to:$0).adding(translation) }
        let velocities=positions.map { _ in Vector3.unitY }
        let after=try DeformingFixtures.snapshot(s,positions:positions,velocities:velocities,revision:2,previous:before)
        let point=try SurfaceMaterialPoint(feature:SurfaceFeatureID(cell:100,oppositeNode:3),barycentric:[0.2,0.3,0.5],sumTolerance:1e-12)
        var work=try DeformingFixtures.work(); let service:any DeformingSurfaceUpdating=TetrahedralBoundaryUpdater()
        let result=try service.point(point,in:after,policy:DeformingFixtures.policy(),work:&work)
        #expect(DeformingFixtures.close(result.position.x,2)); #expect(DeformingFixtures.close(result.position.y,-0.1)); #expect(result.position.z == 2)
        #expect(result.velocity == .unitY); #expect(before.state.positions[0] == .zero)
        do { _=try DeformingFixtures.snapshot(s,positions:positions,revision:1,previous:before); Issue.record("Changed geometry reused its epoch.") }
        catch DeformingContactError.staleGeometry {} catch { throw error }
    }
    @Test func refinementRetainsPhysicalBoundary() throws {
        let mesh=try DeformingFixtures.mesh(), a=try DeformingFixtures.surface(mesh)
        var work=try DeformingFixtures.work(); let producer:any TetrahedralMeshValidating=TetrahedralMeshValidator()
        let refined=try producer.refine(mesh,revision:2,newNodeIdentifiers:[99],newCellIdentifiers:[200,201,202,203],
            admission:MeshAdmission(maximumNodes:100,maximumCells:100,maximumMaterials:2,minimumReferenceVolume:1e-12,inverseRelativeTolerance:1e-12),work:&work)
        let b=try DeformingFixtures.surface(refined)
        #expect(a.triangles.count == 4); #expect(b.triangles.count == 4)
        for face in a.triangles { #expect(b.triangles.contains { Set($0.nodes) == Set(face.nodes) }) }
    }
    @Test func invalidLayoutInversionCancelAndCapacity() throws {
        let mesh=try DeformingFixtures.mesh(), surface=try DeformingFixtures.surface(mesh)
        let service:any DeformingSurfaceUpdating=TetrahedralBoundaryUpdater(); var work=try DeformingFixtures.work()
        do { _=try service.extract(mesh,body:surface.body,policy:DeformingFixtures.policy(cancelled:true),work:&work); Issue.record("Cancelled extraction succeeded.") }
        catch DeformingContactError.cancelled {} catch { throw error }
        do { _=try service.extract(mesh,body:surface.body,policy:DeformingFixtures.policy(faces:3),work:&work); Issue.record("Face capacity was bypassed.") }
        catch DeformingContactError.capacityExceeded {} catch { throw error }
        var points=mesh.mesh.nodes.map { $0.referencePosition }; points.swapAt(1,2)
        do { _=try DeformingFixtures.snapshot(surface,positions:points); Issue.record("Inverted current cell succeeded.") }
        catch DeformingContactError.invertedCell {} catch { throw error }
        let state=NodalState(frame:mesh.mesh.frame,meshRevision:2,nodeIdentifiers:[10,11,12,13],positions:mesh.mesh.nodes.map { $0.referencePosition },velocities:[.zero,.zero,.zero,.zero])
        do { _=try service.update(surface,state:state,geometryRevision:1,time:0,previous:nil,policy:DeformingFixtures.policy(),work:&work); Issue.record("Stale mesh layout succeeded.") }
        catch DeformingContactError.staleMesh {} catch { throw error }
    }
    @Test func foreignSameRevisionOwnerCannotInheritGeometry() throws {
        let a=try DeformingFixtures.surface(DeformingFixtures.mesh()), b=try DeformingFixtures.surface(DeformingFixtures.mesh())
        let previous=try DeformingFixtures.snapshot(a)
        do { _=try DeformingFixtures.snapshot(b,previous:previous); Issue.record("Foreign surface inherited prior authority.") }
        catch DeformingContactError.staleGeometry {} catch { throw error }
        let independent=try DeformingFixtures.snapshot(a)
        #expect(independent.surface === previous.surface); #expect(independent.state.positions == previous.state.positions)
    }
}
