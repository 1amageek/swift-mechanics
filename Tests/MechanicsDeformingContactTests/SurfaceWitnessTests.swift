import Testing
import MechanicsCore
import MechanicsModel
import MechanicsDeformingContact
@Suite struct SurfaceWitnessTests {
    @Test func actualPlaneVertexAndBalance() throws {
        let surface=try DeformingFixtures.surface(DeformingFixtures.mesh())
        var points=surface.mesh.mesh.nodes.map { $0.referencePosition }; points[0]=try Vector3(0,0,-0.01)
        let snapshot=try DeformingFixtures.snapshot(surface,positions:points), plane=try DeformingFixtures.plane()
        var work=try DeformingFixtures.work(), collision=try DeformingFixtures.collisionWork(); let service:any SurfaceWitnessQuerying=SelectedSurfaceWitnessQueries()
        let witness=try service.plane(snapshot,face:SurfaceFeatureID(cell:100,oppositeNode:1),obstacle:plane,obstacleBody:ModelReference(id:plane.geometry.bodyID,revision:1),
            policy:DeformingFixtures.policy(),collisionPolicy:DeformingFixtures.collisionPolicy(),work:&work,collisionWork:&collision)
        #expect(witness.separation == -0.01); #expect(witness.pointB == .zero); #expect(witness.normal == (try Vector3(0,0,-1)))
        #expect(witness.first.barycentric == [1,0,0]); #expect(collision.operations > 0)
    }
    @Test func selfInteriorMaterialProjectionAndAdjacencyFailure() throws {
        let snapshot=try DeformingFixtures.selfSnapshot(); var work=try DeformingFixtures.work(); let service:any SurfaceWitnessQuerying=SelectedSurfaceWitnessQueries()
        let witness=try service.selfContact(snapshot,first:SurfaceFeatureID(cell:101,oppositeNode:1),vertex:0,second:SurfaceFeatureID(cell:100,oppositeNode:3),policy:DeformingFixtures.policy(),work:&work)
        #expect(DeformingFixtures.close(witness.separation,-0.01)); #expect(witness.normal == .unitZ)
        #expect(DeformingFixtures.close(witness.second!.barycentric[0],0.6)); #expect(DeformingFixtures.close(witness.pointB.z,0))
        do { _=try service.selfContact(snapshot,first:SurfaceFeatureID(cell:100,oppositeNode:1),vertex:0,second:SurfaceFeatureID(cell:100,oppositeNode:3),policy:DeformingFixtures.policy(),work:&work); Issue.record("Adjacent faces admitted.") }
        catch DeformingContactError.adjacentPair {} catch { throw error }
    }
    @Test func failedSupplierStopsWithOriginalGeometry() throws {
        let surface=try DeformingFixtures.surface(DeformingFixtures.mesh()), snapshot=try DeformingFixtures.snapshot(surface), plane=try DeformingFixtures.plane()
        var work=try DeformingFixtures.work(), collision=try DeformingFixtures.collisionWork(); let service:any SurfaceWitnessQuerying=SelectedSurfaceWitnessQueries(geometry:FailingPlaneQueries())
        do { _=try service.plane(snapshot,face:SurfaceFeatureID(cell:100,oppositeNode:1),obstacle:plane,obstacleBody:ModelReference(id:plane.geometry.bodyID,revision:1),
            policy:DeformingFixtures.policy(),collisionPolicy:DeformingFixtures.collisionPolicy(),work:&work,collisionWork:&collision); Issue.record("Failed supplier produced a witness.") }
        catch DeformingContactError.collision(_,let unavailable) { #expect(unavailable) } catch { throw error }
        #expect(collision.operations == 64); #expect(snapshot.state.positions[0] == .zero)
    }
    @Test func currentPolicyCapacityAndLongMetadataRejectBeforeLookup() throws {
        let snapshot=try DeformingFixtures.selfSnapshot(), service:any SurfaceWitnessQuerying=SelectedSurfaceWitnessQueries()
        var work=try DeformingFixtures.work(), collision=try DeformingFixtures.collisionWork()
        do { _=try service.selfContact(snapshot,first:SurfaceFeatureID(cell:101,oppositeNode:1),vertex:0,second:SurfaceFeatureID(cell:100,oppositeNode:3),policy:DeformingFixtures.policy(faces:1),work:&work); Issue.record("Prior surface admission bypassed current face capacity.") }
        catch DeformingContactError.capacityExceeded {} catch { throw error }
        let plane=try DeformingFixtures.plane(), long=try ModelReference(id:EntityID(kind:.body,key:String(repeating:"x",count:100)),revision:1)
        do { _=try service.plane(snapshot,face:SurfaceFeatureID(cell:101,oppositeNode:1),obstacle:plane,obstacleBody:long,
            policy:DeformingFixtures.policy(identifiers:32),collisionPolicy:DeformingFixtures.collisionPolicy(),work:&work,collisionWork:&collision); Issue.record("Long body metadata reached semantic comparison.") }
        catch DeformingContactError.capacityExceeded {} catch { throw error }
        #expect(collision.operations == 0)
        do { _=try service.plane(snapshot,face:SurfaceFeatureID(cell:101,oppositeNode:1),obstacle:plane,obstacleBody:ModelReference(id:plane.geometry.bodyID,revision:1),
            policy:DeformingFixtures.policy(faces:1),collisionPolicy:DeformingFixtures.collisionPolicy(),work:&work,collisionWork:&collision); Issue.record("Plane query bypassed current face capacity.") }
        catch DeformingContactError.capacityExceeded {} catch { throw error }
    }
    @Test func unsupportedEdgeProjectionAndQueryCancellation() throws {
        let before=try DeformingFixtures.selfSnapshot()
        var positions=before.state.positions
        for i in 4..<8 { positions[i]=try positions[i].subtracting(Vector3(0.2,0,0)) }
        let edge=try DeformingFixtures.snapshot(before.surface,positions:positions,revision:2,previous:before)
        var work=try DeformingFixtures.work(); let service:any SurfaceWitnessQuerying=SelectedSurfaceWitnessQueries()
        do { _=try service.selfContact(edge,first:SurfaceFeatureID(cell:101,oppositeNode:1),vertex:0,second:SurfaceFeatureID(cell:100,oppositeNode:3),policy:DeformingFixtures.policy(),work:&work); Issue.record("Unsupported edge projection admitted.") }
        catch DeformingContactError.outsideInterior {} catch { throw error }
        do { _=try service.selfContact(before,first:SurfaceFeatureID(cell:101,oppositeNode:1),vertex:0,second:SurfaceFeatureID(cell:100,oppositeNode:3),policy:DeformingFixtures.policy(cancelled:true),work:&work); Issue.record("Cancelled query admitted.") }
        catch DeformingContactError.cancelled {} catch { throw error }
    }
}
