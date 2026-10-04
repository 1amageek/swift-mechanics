import SwiftMechanics
import Testing
import Foundation

@Suite(.timeLimit(.minutes(1)))
struct ToothMaterialPhysicalTests {
    private func assertOriginal(_ state: MaterialToothContactState, old: ContactHistory? = nil, step: Double? = nil, mixed: Bool = false) throws {
        let oracle=try ToothMaterialOracle.evaluate(model:state.model,q:state.physical.q,v:state.physical.v,history:old ?? state.histories[0],step:step,mixed:mixed)
        let observation=state.observations[0]
        #expect(ToothFixtures.close(observation.witness.separation,oracle.separation))
        for (supplied,expected) in [(observation.applicationPoint,oracle.point),(observation.relativePointVelocity,oracle.relative),
            (observation.relativeAngularVelocity,oracle.angular),(observation.forceOnB,oracle.force),(observation.coupleOnB,oracle.couple),
            (observation.torqueAtFirstBodyOrigin,oracle.torqueA),(observation.torqueAtSecondBodyOrigin,oracle.torqueB)] {
            #expect(ToothFixtures.close(supplied.x,expected.x) && ToothFixtures.close(supplied.y,expected.y) && ToothFixtures.close(supplied.z,expected.z))
        }
        for i in 0..<2 { #expect(ToothFixtures.close(state.physical.acceleration[i],oracle.acceleration[i])) }
        #expect(ToothFixtures.close(state.energy.kineticEnergy,oracle.kinetic))
        #expect(ToothFixtures.close(state.energy.kineticEnergyRate,oracle.kineticRate))
        #expect(ToothFixtures.close(state.normalStoredEnergy,oracle.normal))
        #expect(ToothFixtures.close(state.tangentialStoredEnergy,oracle.tangent))
        #expect(ToothFixtures.close(state.cohesivePotentialEnergy,oracle.cohesion))
        #expect(ToothFixtures.close(state.normalDissipationPower,oracle.dn))
        #expect(ToothFixtures.close(state.resistanceDissipationPower,oracle.dr))
        if step != nil {
            #expect(ToothFixtures.close(observation.tangentialDissipationEnergy,oracle.dt))
            #expect(ToothFixtures.close(state.histories[0].firstBristleDisplacement,oracle.z1))
            #expect(ToothFixtures.close(state.histories[0].secondBristleDisplacement,oracle.z2))
        }
    }
    @Test(arguments:[0,1,2,3]) func actualFullMaterialArbitraryInitialSlipAndOneEndpoint(normal: Int) throws {
        let model=try ToothMaterialFixtures.model(normal:normal,rotated:true,mixed:true)
        let initial=try ToothMaterialFixtures.initial(model,v:[0.8,-0.7])
        try assertOriginal(initial,mixed:true)
        #expect(initial.histories[0].sequence == 0 && initial.histories[0].timeSeconds == 0)
        #expect(initial.histories[0].firstBristleDisplacement == 0 && initial.histories[0].secondBristleDisplacement == 0)
        #expect(initial.resistanceDissipationPower > 0 && initial.cohesivePotentialEnergy < 0)
        var work=try ToothFixtures.work()
        let next=try ToothMaterialFixtures.service(model).stepMaterial(accepted:initial,timeStep:0.001,policy:ToothFixtures.policy(defect:100),work:&work)
        try assertOriginal(next,old:initial.histories[0],step:0.001,mixed:true)
        #expect(next.histories[0].sequence == 1 && next.histories[0].timeSeconds == 0.001)
        #expect(next.histories[0].firstBristleDisplacement != 0 && next.histories[0].secondBristleDisplacement != 0)
        let pairPower=try next.observations[0].forceOnB.dot(next.observations[0].relativePointVelocity)+next.observations[0].coupleOnB.dot(next.observations[0].relativeAngularVelocity)
        #expect(ToothFixtures.close(next.observations[0].relativeMechanicalPower,pairPower))
        #expect(ToothFixtures.close(next.accumulatedTangentialDissipation,next.histories[0].cumulativeTangentialDissipation))
        // Equal/opposite force at one point and equal/opposite couples leave no pair moment.
        let firstIsA=model.teeth[model.contacts[0].firstProxy].proxy.geometry.bodyID.key == "tooth-a"
        let offset=try model.tree.bodies[0].referencePose.rotation.rotating(Vector3(firstIsA ? 2 : -2,0,0))
        let moment=try next.observations[0].torqueAtFirstBodyOrigin.adding(next.observations[0].torqueAtSecondBodyOrigin)
            .adding(offset.cross(next.observations[0].forceOnB))
        #expect(try moment.magnitude() < 1e-9)
        #expect(initial.histories[0].sequence == 0)
    }
    @Test func anisotropicSlidingAndLossAreOriginalIssuedHistory() throws {
        let model=try ToothMaterialFixtures.model(cohesion:false,resistance:false,mixed:true)
        let initial=try ToothMaterialFixtures.initial(model,v:[20,-5])
        var work=try ToothFixtures.work()
        let next=try ToothMaterialFixtures.service(model).stepMaterial(accepted:initial,timeStep:0.01,policy:ToothFixtures.policy(defect:100),work:&work)
        try assertOriginal(next,old:initial.histories[0],step:0.01,mixed:true)
        guard case .trial(let response)=next.observations[0].evidence else { Issue.record("Endpoint evidence is not a real trial."); return }
        let original=try ToothMaterialOracle.evaluate(model:model,q:next.physical.q,v:next.physical.v,history:initial.histories[0],step:0.01,mixed:true)
        #expect(original.trialStaticUtilization > 1)
        #expect(response.frictionRegime == .sliding)
        #expect(next.accumulatedTangentialDissipation > 0 && next.accumulatedNormalDissipation == 0 && next.accumulatedResistanceDissipation == 0)
        work=try ToothFixtures.work()
        let later=try ToothMaterialFixtures.service(model).stepMaterial(accepted:next,timeStep:0.001,policy:ToothFixtures.policy(defect:100),work:&work)
        #expect(later.histories[0].sequence == 2)
    }
    @Test func compressedOpeningAndOpenCohesionRemainConservative() throws {
        let model=try ToothMaterialFixtures.model(friction:false,resistance:false)
        for angle in [-0.1,0.1,0.4] {
            let state=try ToothMaterialFixtures.initial(model,q:[angle,angle],v:[0.3,0.5])
            try assertOriginal(state)
            #expect(state.accumulatedDissipation == 0)
            #expect(ToothFixtures.close(state.observations[0].completeCohesiveSeparationWork,0.03))
        }
        let initial=try ToothMaterialFixtures.initial(model,v:[4,4])
        let coarse=try ToothMaterialFixtures.advance(model,initial:initial,step:0.004,end:0.08)
        let fine=try ToothMaterialFixtures.advance(model,initial:initial,step:0.002,end:0.08)
        let finer=try ToothMaterialFixtures.advance(model,initial:initial,step:0.001,end:0.08)
        #expect(coarse.cohesivePotentialEnergy == 0 && finer.cohesivePotentialEnergy == 0)
        #expect(coarse.accumulatedDissipation == 0 && finer.accumulatedDissipation == 0)
        #expect(abs(fine.originalEnergyDefect) < abs(coarse.originalEnergyDefect))
        #expect(abs(finer.originalEnergyDefect) < abs(fine.originalEnergyDefect))
        let opening=0.03
        #expect(ToothFixtures.close(finer.cohesivePotentialEnergy-initial.cohesivePotentialEnergy,opening))
    }
    @Test(arguments:[1,2,3]) func drivenNonlinearFrictionResistanceRefineAndReplay(normal: Int) throws {
        let model=try ToothMaterialFixtures.model(normal:normal,mixed:true), initial=try ToothMaterialFixtures.initial(model)
        let a=try ToothMaterialFixtures.advance(model,initial:initial,step:0.002)
        let b=try ToothMaterialFixtures.advance(model,initial:initial,step:0.001)
        let c=try ToothMaterialFixtures.advance(model,initial:initial,step:0.0005)
        let errorAB=zip(a.physical.q,b.physical.q).reduce(0.0){$0+abs($1.0-$1.1)}+zip(a.physical.v,b.physical.v).reduce(0.0){$0+abs($1.0-$1.1)}
        let errorBC=zip(b.physical.q,c.physical.q).reduce(0.0){$0+abs($1.0-$1.1)}+zip(b.physical.v,c.physical.v).reduce(0.0){$0+abs($1.0-$1.1)}
        #expect(errorBC < errorAB && abs(c.originalEnergyDefect) < abs(a.originalEnergyDefect))
        try assertOriginal(c,mixed:true)
        let fresh=try ToothMaterialFixtures.model(normal:normal,mixed:true)
        var work=try ToothFixtures.work()
        let replay=try ToothMaterialFixtures.service(fresh).advanceMaterial(accepted:initial,to:0.02,timeStep:0.0005,policy:ToothFixtures.policy(defect:100),work:&work).accepted
        #expect(replay.physical == c.physical && replay.histories == c.histories)
        #expect(replay.accumulatedDriveWork == c.accumulatedDriveWork && replay.accumulatedDissipation == c.accumulatedDissipation)
        #expect(c.physical.q != initial.physical.q && c.accumulatedTangentialDissipation > 0 && c.accumulatedResistanceDissipation > 0)
    }
    @Test func actualOpeningReleasesAcceptedSpringWithoutDoubleAdvance() throws {
        let model=try ToothMaterialFixtures.model(cohesion:false,resistance:false), initial=try ToothMaterialFixtures.initial(model,v:[4,2])
        let policy=try ToothFixtures.policy(defect:100), service=ToothMaterialFixtures.service(model)
        var current=initial, released=false
        for _ in 0..<150 {
            var work=try ToothFixtures.work()
            let next=try service.stepMaterial(accepted:current,timeStep:0.001,policy:policy,work:&work)
            try assertOriginal(next,old:current.histories[0],step:0.001)
            if case .trial(let response)=next.observations[0].evidence, response.frictionRegime == .released,
               current.tangentialStoredEnergy > 0 {
                #expect(ToothFixtures.close(response.tangentialDissipationEnergy,current.tangentialStoredEnergy))
                #expect(next.tangentialStoredEnergy == 0)
                released=true; break
            }
            current=next
        }
        #expect(released)
    }
    @Test func clippedDampingRetainsOriginalContinuousLoss() throws {
        let model=try ToothMaterialFixtures.model(normal:1,friction:false,cohesion:false,resistance:false)
        let state=try ToothMaterialFixtures.initial(model,v:[4,4])
        try assertOriginal(state)
        #expect(state.observations[0].forceOnB == .zero && state.normalDissipationPower > 0)
    }
}
