import SwiftMechanics
import Testing
@Suite struct NodalForceTests {
    private func response(_ snapshot: DeformingSurfaceSnapshot) throws -> SurfaceForceTrial {
        let witness=try DeformingFixtures.selfWitness(snapshot), pair=try DeformingFixtures.pair()
        var work=try DeformingFixtures.work(), law=try DeformingFixtures.lawWork(); let mapper:any SurfaceContactForceMapping=MaterialSurfaceForceMapper()
        let history=try mapper.initialHistory(witness,key:"self",pair:pair,policy:DeformingFixtures.policy(),work:&work,lawWork:&law)
        return try mapper.evaluate(witness,current:snapshot,currentObstacle:nil,key:"self",pair:pair,accepted:history,timeStep:0.001,
            policy:DeformingFixtures.policy(),lawPolicy:DeformingFixtures.lawPolicy(),work:&work,lawWork:&law)
    }
    @Test func selfFrictionAnalyticForceMomentAndEnergy() throws {
        let snapshot=try DeformingFixtures.selfMoving(), result=try response(snapshot)
        #expect(result.response.trialHistory.identity.firstBody == result.response.trialHistory.identity.secondBody)
        #expect(result.response.trialHistory.identity.firstMaterialSite != result.response.trialHistory.identity.secondMaterialSite)
        #expect(DeformingFixtures.close(result.response.forceOnB.x,1)); #expect(DeformingFixtures.close(result.response.forceOnB.z,10))
        #expect(DeformingFixtures.close(result.nodalForces[4].x,-1)); #expect(DeformingFixtures.close(result.nodalForces[4].z,-10))
        #expect(DeformingFixtures.close(result.response.tangentialStoredEnergy,0.0005)); #expect(DeformingFixtures.close(result.response.tangentialDissipationEnergy,0.0005))
        var force=Vector3.zero,moment=Vector3.zero
        for i in result.nodalForces.indices { force=try force.adding(result.nodalForces[i]); moment=try moment.adding(snapshot.state.positions[i].cross(result.nodalForces[i])) }
        #expect(try force.magnitude() < 1e-9); #expect(try moment.magnitude() < 1e-9); #expect(DeformingFixtures.close(result.mappedPower,-1))
    }
    @Test func independentCentralVirtualWorkAndRigidCovariance() throws {
        let snapshot=try DeformingFixtures.selfMoving(), result=try response(snapshot), witness=result.witness
        let face=snapshot.surface.triangles.first { $0.feature == witness.second!.feature }!
        let weights=witness.second!.barycentric, h=1e-6
        var virtual: [Vector3]=[]
        for i in snapshot.state.positions.indices { virtual.append(try Vector3(Double(i+1)*0.03,Double(2-i)*0.02,Double(i%3)*0.04)) }
        func lifted(_ sign: Double) throws -> Vector3 {
            var positions=snapshot.state.positions
            for i in positions.indices { positions[i]=try positions[i].adding(virtual[i].scaled(by:sign*h)) }
            let a=positions[face.nodes[0]], u=try positions[face.nodes[1]].subtracting(a), v=try positions[face.nodes[2]].subtracting(a)
            let normal=try u.cross(v).normalized()
            var point=Vector3.zero
            for i in 0..<3 { point=try point.adding(positions[face.nodes[i]].scaled(by:weights[i])) }
            return try point.adding(normal.scaled(by:witness.separation)).subtracting(positions[4])
        }
        let jacobianDirection=try lifted(1).subtracting(lifted(-1)).scaled(by:1/(2*h))
        let direct=try result.response.forceOnB.dot(jacobianDirection)
        var mapped=0.0
        for i in virtual.indices { mapped += try result.nodalForces[i].dot(virtual[i]) }
        #expect(DeformingFixtures.close(direct,mapped,tolerance:1e-7))
        let rotation=try UnitQuaternion(axis:.unitY,angle:0.7), rotated=try response(DeformingFixtures.selfMoving(rotation:rotation))
        for i in result.nodalForces.indices { #expect(try rotation.rotating(result.nodalForces[i]).subtracting(rotated.nodalForces[i]).magnitude() < 1e-8) }
        #expect(DeformingFixtures.close(rotated.mappedPower,result.mappedPower))
    }
    @Test func staleGeometryForeignAuthorityAndFailedWork() throws {
        let s=try DeformingFixtures.selfMoving(), witness=try DeformingFixtures.selfWitness(s), pair=try DeformingFixtures.pair()
        var work=try DeformingFixtures.work(), law=try DeformingFixtures.lawWork(); let mapper:any SurfaceContactForceMapping=MaterialSurfaceForceMapper()
        let history=try mapper.initialHistory(witness,key:"self",pair:pair,policy:DeformingFixtures.policy(),work:&work,lawWork:&law)
        let foreign=try DeformingFixtures.selfMoving()
        do { _=try mapper.evaluate(witness,current:foreign,currentObstacle:nil,key:"self",pair:pair,accepted:history,timeStep:0.001,policy:DeformingFixtures.policy(),lawPolicy:DeformingFixtures.lawPolicy(),work:&work,lawWork:&law); Issue.record("Foreign surface reused revision authority.") }
        catch DeformingContactError.staleGeometry {} catch { throw error }
        var exhausted=try DeformingFixtures.lawWork(operations:0)
        do { _=try mapper.evaluate(witness,current:s,currentObstacle:nil,key:"self",pair:pair,accepted:history,timeStep:0.001,policy:DeformingFixtures.policy(),lawPolicy:DeformingFixtures.lawPolicy(),work:&work,lawWork:&exhausted); Issue.record("Failed law produced forces.") }
        catch DeformingContactError.law(_,let unavailable) { #expect(unavailable) } catch { throw error }
        #expect(history.sequence == 0); #expect(s.state.positions[4] == (try Vector3(0.2,0.2,0.01)))
    }
    @Test func supplierLedgerReplacementIsUnavailableAndRestoresAuthoritativePrefix() throws {
        let s=try DeformingFixtures.selfMoving(), witness=try DeformingFixtures.selfWitness(s), pair=try DeformingFixtures.pair()
        var work=try DeformingFixtures.work(), law=try DeformingFixtures.lawWork(); let regular:any SurfaceContactForceMapping=MaterialSurfaceForceMapper()
        let history=try regular.initialHistory(witness,key:"self",pair:pair,policy:DeformingFixtures.policy(),work:&work,lawWork:&law)
        let before=law.operations, invalid:any SurfaceContactForceMapping=MaterialSurfaceForceMapper(laws:ResettingContactLaw())
        do { _=try invalid.evaluate(witness,current:s,currentObstacle:nil,key:"self",pair:pair,accepted:history,timeStep:0.001,policy:DeformingFixtures.policy(),lawPolicy:DeformingFixtures.lawPolicy(),work:&work,lawWork:&law); Issue.record("Reset ledger was accepted.") }
        catch DeformingContactError.supplierLedgerReplaced {} catch { throw error }
        #expect(law.operations == before); #expect(history.sequence == 0)
    }
}
