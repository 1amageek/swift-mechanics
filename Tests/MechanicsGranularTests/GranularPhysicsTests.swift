import SwiftMechanics
import Testing

struct GranularPhysicsTests {
    @Test func twoSphereImpulseAndIndependentWork() throws {
        let state=try GranularFixtures.prepare(motions:[GranularMotion(position:Vector3(-0.49,0,0),velocity:.unitX),GranularMotion(position:Vector3(0.49,0,0),velocity:Vector3(-1,0,0))])
        var workspace=GranularWorkspace()
        let result=try GranularFixtures.step(state,workspace:&workspace)
        #expect(result.neighbors.count == 1)
        #expect(GranularFixtures.close(result.contacts[0].response.compressiveNormalForce,20))
        #expect(GranularFixtures.close(result.state.motions[0].velocity.x,0.98))
        #expect(GranularFixtures.close(result.state.motions[1].velocity.x,-0.98))
        #expect(GranularFixtures.close(result.evidence.kineticEnergyChange,-0.0396))
        #expect(GranularFixtures.close(result.evidence.particleMidpointWork,-0.0396))
        #expect(result.evidence.originalWorkResidual < 1e-10)
        #expect(state.motions[0].velocity == .unitX && state.contacts[0].history.sequence == 0)
    }
    @Test func frictionalPairPreservesWorldAngularMomentumAtCommonPort() throws {
        let initial=try GranularFixtures.prepare(motions:[GranularMotion(position:Vector3(-0.49,0,0),velocity:.unitY),GranularMotion(position:Vector3(0.49,0,0),velocity:Vector3(0,-1,0))],friction:true)
        var workspace=GranularWorkspace(); let result=try GranularFixtures.step(initial,workspace:&workspace)
        func angularMomentum(_ state: GranularState) throws -> Vector3 {
            var total=Vector3.zero
            for i in state.motions.indices {
                let p=state.model.particles[i], motion=state.motions[i]
                total=try total.adding(motion.position.cross(motion.velocity.scaled(by:p.mass))).adding(motion.angularVelocity.scaled(by:p.momentOfInertia))
            }
            return total
        }
        let residual=try angularMomentum(result.state).subtracting(angularMomentum(initial)).magnitude()
        #expect(residual < 1e-10)
        #expect(result.state.motions[0].angularVelocity.z < 0 && result.state.motions[1].angularVelocity.z < 0)
        #expect(result.contacts[0].response.tangentialStoredEnergy > 0 && result.contacts[0].response.frictionConeUtilization < 1)
    }
    @Test func movingPlaneShearIncludesTorqueBoundaryWorkAndSpringHistory() throws {
        let state=try GranularFixtures.prepare(motions:[GranularMotion(position:Vector3(0,0,0.49))],plane:true,planeVelocity:.unitX,friction:true)
        var workspace=GranularWorkspace()
        let result=try GranularFixtures.step(state,workspace:&workspace)
        #expect(GranularFixtures.close(result.state.motions[0].velocity.x,0.0001))
        #expect(GranularFixtures.close(result.state.motions[0].velocity.z,0.01))
        #expect(GranularFixtures.close(result.state.motions[0].angularVelocity.y,-0.000495))
        #expect(GranularFixtures.close(result.boundaryReactions[0].force.x,-0.1))
        #expect(GranularFixtures.close(result.evidence.prescribedBoundaryWork,-0.0001))
        #expect(GranularFixtures.close(result.contacts[0].response.tangentialStoredEnergy,0.00005))
        #expect(GranularFixtures.close(result.contacts[0].response.tangentialDissipationEnergy,0.00005))
        #expect(result.contacts[0].response.frictionRegime == .sticking)
        #expect(result.evidence.maximumAngularImpulseResidual < 1e-10)
        let next=try GranularFixtures.step(result.state,workspace:&workspace)
        #expect(next.state.contacts[0].history.sequence == 2)
        #expect(next.state.contacts[0].history.firstBristleDisplacement > result.state.contacts[0].history.firstBristleDisplacement)
    }
    @Test func cohesiveOpenNeighborsAttractWithoutCompression() throws {
        let state=try GranularFixtures.prepare(motions:[GranularMotion(position:Vector3(-0.525,0,0)),GranularMotion(position:Vector3(0.525,0,0))],cohesion:true)
        var workspace=GranularWorkspace(); let result=try GranularFixtures.step(state,workspace:&workspace)
        #expect(result.neighbors.count == 1)
        #expect(result.contacts[0].response.compressiveNormalForce == 0)
        #expect(GranularFixtures.close(result.contacts[0].response.cohesiveNormalForce,-5))
        #expect(GranularFixtures.close(result.state.motions[0].velocity.x,0.005))
        #expect(GranularFixtures.close(result.state.motions[1].velocity.x,-0.005))
        #expect(GranularFixtures.close(result.contacts[0].response.cohesivePotentialEnergy,-0.125))
    }
    @Test func rotatedPlaneUsesActualFramedNormal() throws {
        let rotation=try UnitQuaternion(axis:.unitY,angle:Double.pi/2)
        let state=try GranularFixtures.prepare(motions:[GranularMotion(position:Vector3(0.49,0,0))],plane:true,rotation:rotation)
        var workspace=GranularWorkspace(); let result=try GranularFixtures.step(state,workspace:&workspace)
        #expect(GranularFixtures.close(result.state.motions[0].velocity.x,0.01))
        #expect(abs(result.state.motions[0].velocity.z) < 1e-10)
        #expect(GranularFixtures.close(result.boundaryReactions[0].force.x,-10))
        #expect(result.boundaryReactions[0].frame == state.model.frame)
    }
    @Test func elasticCollisionTimeRefinementMatchesOscillator() throws {
        let state=try GranularFixtures.prepare(motions:[GranularMotion(position:Vector3(-0.49,0,0)),GranularMotion(position:Vector3(0.49,0,0))])
        func run(_ h: Double,_ count: Int) throws -> Double {
            var current=state, workspace=GranularWorkspace()
            for _ in 0..<count { current=try GranularFixtures.step(current,h:h,workspace:&workspace).state }
            return current.motions[1].velocity.x
        }
        let omega=2000.0.squareRoot(), exact=0.01*omega*(try sinValue(omega*0.01))
        let coarse=try run(0.002,5), fine=try run(0.0001,100)
        #expect(abs(fine-exact) < abs(coarse-exact))
        #expect(abs(fine-exact) < 0.001)
    }
    @Test func threeParticleColumnActuallySettlesWithGravityAndDamping() throws {
        let state=try GranularFixtures.prepare(motions:[GranularMotion(position:Vector3(0,0,0.7)),GranularMotion(position:Vector3(0,0,1.9)),GranularMotion(position:Vector3(0,0,3.1))],plane:true,damping:100)
        var current=state, workspace=GranularWorkspace(), reaction=0.0, loss=0.0
        for _ in 0..<6000 {
            let result=try GranularFixtures.step(current,gravity:Vector3(0,0,-9.81),workspace:&workspace)
            current=result.state; reaction=result.boundaryReactions[0].force.z; loss += result.evidence.constitutiveDissipationEnergy
        }
        #expect(abs(reaction+29.43) < 0.03)
        #expect(abs(current.motions[0].position.z-(0.5-29.43/1000)) < 0.0001)
        #expect(abs(current.motions[1].position.z-current.motions[0].position.z-(1-19.62/1000)) < 0.0001)
        #expect(abs(current.motions[2].position.z-current.motions[1].position.z-(1-9.81/1000)) < 0.0001)
        for motion in current.motions { #expect(abs(motion.velocity.z) < 0.001) }
        #expect(loss > 0)
    }
    private func sinValue(_ angle: Double) throws -> Double {
        try UnitQuaternion(axis:.unitZ,angle:angle).rotating(.unitX).y
    }
}
