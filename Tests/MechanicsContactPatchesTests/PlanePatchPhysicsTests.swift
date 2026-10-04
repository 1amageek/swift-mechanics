import SwiftMechanics
import Testing
@Suite(.timeLimit(.minutes(1)))
struct PlanePatchPhysicsTests {
    @Test func affineLoadedTriangleExactMomentNodalLoadsAndPrescribedPower() throws {
        let mesh=try PatchFixtures.mesh(), body=try PatchFixtures.body(mesh), result=try PatchFixtures.solve(body,PatchFixtures.plane(mesh.mesh.frame))
        let l=0.8, area=l*l/2, pressure=3*area+7*l*l*l/6
        let xp=3*l*l*l/6+3*l*l*l*l/12+4*l*l*l*l/24
        let yp=3*l*l*l/6+3*l*l*l*l/24+4*l*l*l*l/12
        #expect(result.triangles.count == 1); #expect(PatchFixtures.close(result.area,area)); #expect(PatchFixtures.close(result.integratedPressure,pressure))
        #expect(try PatchFixtures.close(result.wrenchOnRigid.force,Vector3(0,0,pressure)))
        #expect(try PatchFixtures.close(result.wrenchOnRigid.torque,Vector3(yp,-xp,0)))
        let loads=[l*pressure-xp-yp,xp,yp,0.2*pressure]
        for i in 0..<4 { #expect(PatchFixtures.close(result.nodalForces[i].z,-loads[i])) }
        #expect(PatchFixtures.close(result.compliantPower,-(1.6*pressure+xp+2*yp)))
        #expect(PatchFixtures.close(result.rigidPower,0.5*pressure+yp))
        #expect(result.originalForceResidual < 1e-8 && result.originalMomentResidual < 1e-8 && result.originalPowerResidual < 1e-8)
        #expect(result.source == mesh.mesh.source && result.meshRevision == 1 && result.pressureRevision == 3)
        #expect(body.field?.pressurePascals == [2,5,6,7])
    }
    @Test func quadrilateralCutAndNormalReversalPreserveOppositeWrenchConvention() throws {
        let mesh=try PatchFixtures.mesh(), body=try PatchFixtures.body(mesh,constant:true)
        let n=try Vector3(1,1,0).normalized(), point=try Vector3(0.2,0.2,0)
        let result=try PatchFixtures.solve(body,PatchFixtures.plane(mesh.mesh.frame,normal:n,point:point))
        #expect(result.triangles.count == 2); #expect(PatchFixtures.close(result.area,0.24*Double(2).squareRoot()))
        #expect(try PatchFixtures.close(result.wrenchOnRigid.force,Vector3(1.2,1.2,0)))
        #expect(try PatchFixtures.close(result.wrenchOnRigid.torque,Vector3(-0.36,0.36,0)))
        let reverse=try PatchFixtures.solve(body,PatchFixtures.plane(mesh.mesh.frame,normal:n.scaled(by:-1),point:point))
        #expect(PatchFixtures.close(reverse.wrenchOnRigid.force,result.wrenchOnCompliant.force))
        #expect(PatchFixtures.close(reverse.wrenchOnRigid.torque,result.wrenchOnCompliant.torque))
    }
    @Test func referenceTransformAndOriginTransportHaveActualCovariantWrenches() throws {
        let mesh=try PatchFixtures.mesh(), rotation=try UnitQuaternion(axis:.unitZ,angle:0.7), translation=try Vector3(2,-3,4)
        let pose=RigidTransform(rotation:rotation,translation:translation), base=try PatchFixtures.solve(PatchFixtures.body(mesh),PatchFixtures.plane(mesh.mesh.frame))
        let changed=try PatchFixtures.solve(PatchFixtures.body(mesh,transform:pose),PatchFixtures.plane(mesh.mesh.frame,transform:pose),origin:translation)
        #expect(try PatchFixtures.close(changed.wrenchOnRigid.force,pose.transforming(direction:base.wrenchOnRigid.force)))
        #expect(try PatchFixtures.close(changed.wrenchOnRigid.torque,pose.transforming(direction:base.wrenchOnRigid.torque)))
        #expect(PatchFixtures.close(changed.totalPower,base.totalPower))
        let originZero=try PatchFixtures.solve(PatchFixtures.body(mesh,transform:pose),PatchFixtures.plane(mesh.mesh.frame,transform:pose))
        #expect(try PatchFixtures.close(originZero.wrenchOnRigid.torque,changed.wrenchOnRigid.torque.adding(translation.cross(changed.wrenchOnRigid.force))))
    }
    @Test func actualCentroidRefinementPreservesAffinePressureIntegralsAndVirtualWork() throws {
        let mesh=try PatchFixtures.mesh(), original=try PatchFixtures.solve(PatchFixtures.body(mesh),PatchFixtures.plane(mesh.mesh.frame))
        var supplierWork=try PatchFixtures.work()
        let refined=try TetrahedralMeshValidator().refine(mesh,revision:2,newNodeIdentifiers:[20],newCellIdentifiers:[101,102,103,104],admission:PatchFixtures.admission(),work:&supplierWork)
        let result=try PatchFixtures.solve(PatchFixtures.body(refined),PatchFixtures.plane(refined.mesh.frame))
        #expect(PatchFixtures.close(result.area,original.area)); #expect(PatchFixtures.close(result.integratedPressure,original.integratedPressure))
        #expect(PatchFixtures.close(result.wrenchOnRigid.force,original.wrenchOnRigid.force)); #expect(PatchFixtures.close(result.wrenchOnRigid.torque,original.wrenchOnRigid.torque))
        #expect(PatchFixtures.close(result.compliantPower,original.compliantPower)); #expect(PatchFixtures.close(result.rigidPower,original.rigidPower))
        #expect(result.materialIdentifiers == original.materialIdentifiers && result.source == original.source)
        #expect(supplierWork.operations > 0)
    }
    @Test func genuinelyNonintersectingPlaneHasEmptyPatchWithZeroIntegratedPressure() throws {
        let mesh=try PatchFixtures.mesh(), result=try PatchFixtures.solve(PatchFixtures.body(mesh),PatchFixtures.plane(mesh.mesh.frame,point:Vector3(0,0,2)))
        #expect(result.triangles.isEmpty && result.area == 0 && result.integratedPressure == 0)
        #expect(result.wrenchOnRigid.force == .zero && result.wrenchOnRigid.torque == .zero)
    }
}
