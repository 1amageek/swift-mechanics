import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ToothPhysicalTests {
    @Test func actualWitnessForceTorqueSlipAndOriginalInertia() throws {
        let model=try ToothFixtures.model(), (ia,ib)=try ToothFixtures.indices(model)
        var velocity=[Double](repeating:0,count:2); velocity[ia]=0.3; velocity[ib] = -0.2
        let state=try ToothFixtures.initial(model,v:velocity), p=ToothOracle.pair(qa:0,qb:0,va:0.3,vb:-0.2)
        let report=state.observations[0], firstIsA=model.teeth[0].proxy.geometry.bodyID == (try ToothFixtures.id(.body,"tooth-a"))
        let sign=firstIsA ? 1.0 : -1.0
        #expect(ToothFixtures.close(report.witness.separation,p.separation))
        #expect(ToothFixtures.close(report.witness.normal.y,sign*p.normal[1]))
        #expect(ToothFixtures.close(report.witness.pointA.y,firstIsA ? p.pointA[1] : p.pointB[1]))
        #expect(ToothFixtures.close(report.response.compressiveNormalForce,p.force))
        #expect(ToothFixtures.close(state.generalizedContactForce[ia],p.torques[0]))
        #expect(ToothFixtures.close(state.generalizedContactForce[ib],p.torques[1]))
        #expect(ToothFixtures.close(state.physical.acceleration[ia],-2+p.torques[0]))
        #expect(ToothFixtures.close(state.physical.acceleration[ib],-0.25+p.torques[1]))
        #expect(ToothFixtures.close(report.relativePointVelocity.x,sign*p.relative[0]))
        #expect(ToothFixtures.close(report.slipVelocity.x,sign*p.slip[0]))
        #expect(ToothFixtures.close(state.energy.kineticEnergy,0.5*(0.09+0.04)))
        #expect(ToothFixtures.close(state.contactStoredEnergy,p.potential))
        #expect(ToothFixtures.close(state.energy.kineticEnergyRate,(-2+p.torques[0])*0.3+(-0.25+p.torques[1])*(-0.2)))
        #expect(state.observations[0].witness.approximationError == 0.12)
        #expect(state.histories[0].sequence == 0 && state.histories[0].timeSeconds == 0)
        #expect(state.observations[0].response.trialHistory.sequence == 1)
    }
    @Test func separatedToothRetainsSlipAndDriveWithoutAnIdealRatio() throws {
        let model=try ToothFixtures.model(), (ia,ib)=try ToothFixtures.indices(model)
        var q=[Double](repeating:0,count:2), v=q
        q[ia]=1; q[ib] = -1; v[ia]=0.4; v[ib]=0.7
        var work=try ToothFixtures.work()
        let state=try ReferenceToothContactEvolution(model:model).initial(time:0,q:q,v:v,evaluationTimeStep:0.001,policy:ToothFixtures.policy(),work:&work)
        #expect(state.observations[0].witness.separation > 0)
        #expect(state.generalizedContactForce == [0,0])
        #expect(state.physical.acceleration == model.driveForce)
        #expect(state.contactStoredEnergy == 0)
        #expect(try state.observations[0].slipVelocity.magnitude() > 0)
        #expect(state.physical.v[ia] != -state.physical.v[ib])
    }
    @Test func physicalMeshRefinementApproachesIndependentFlankIntegral() throws {
        let reference=ToothOracle.distributedTorque(256)
        var errors:[Double]=[]
        for count in [2,4,8] {
            let model=try ToothFixtures.model(mesh:count), (ia,_)=try ToothFixtures.indices(model)
            let state=try ToothFixtures.initial(model)
            let quadrature=ToothOracle.distributedTorque(count)
            #expect(ToothFixtures.close(state.generalizedContactForce[ia],quadrature))
            #expect(state.observations.count == count*count)
            #expect(state.observations.allSatisfy{$0.witness.approximationError == 0.12/Double(count)})
            errors.append(abs(state.generalizedContactForce[ia]-reference))
        }
        #expect(errors[1] < errors[0]/3)
        #expect(errors[2] < errors[1]/3)
    }
    @Test func drivenEvolutionTimeRefinementOriginalEndpointAndWork() throws {
        let model=try ToothFixtures.model(), (ia,ib)=try ToothFixtures.indices(model), policy=try ToothFixtures.policy()
        let service:any ToothContactEvolving=ReferenceToothContactEvolution(model:model), initial=try ToothFixtures.initial(model)
        let reference=ToothOracle.integrated(to:0.1)
        var errors:[Double]=[], defects:[Double]=[]
        for dt in [0.002,0.001,0.0005] {
            var work=try ToothFixtures.work()
            let result=try service.advance(accepted:initial,to:0.1,timeStep:dt,policy:policy,work:&work), state=result.accepted
            let q=state.physical.q, v=state.physical.v, p=ToothOracle.pair(qa:q[ia],qb:q[ib],va:v[ia],vb:v[ib])
            errors.append(abs(q[ia]-reference[0])+abs(q[ib]-reference[1])+abs(v[ia]-reference[2])+abs(v[ib]-reference[3]))
            defects.append(abs(state.originalEnergyDefect))
            #expect(state.physical.time == 0.1)
            #expect(state.physical.q != initial.physical.q && state.physical.v != initial.physical.v)
            #expect(ToothFixtures.close(state.physical.acceleration[ia],-2+p.torques[0]))
            #expect(ToothFixtures.close(state.physical.acceleration[ib],-0.25+p.torques[1]))
            #expect(ToothFixtures.close(state.energy.kineticEnergy,0.5*(v[ia]*v[ia]+v[ib]*v[ib])))
            #expect(ToothFixtures.close(state.accumulatedDriveWork,-2*q[ia]-0.25*q[ib]))
            #expect(ToothFixtures.close(state.originalEnergyDefect,state.energy.kineticEnergy+p.potential-initial.initialTotalEnergy-state.accumulatedDriveWork))
            #expect(state.histories.allSatisfy{$0.timeSeconds == 0.1 && $0.sequence == state.acceptedSteps})
            #expect(work.operations > 0 && work.supplierCalls > 0)
        }
        #expect(errors[1] < errors[0]*0.65 && errors[2] < errors[1]*0.65)
        #expect(defects[1] < defects[0]*0.65 && defects[2] < defects[1]*0.65)
    }
    @Test func savedAcceptedValueFreshSourceReplayIsExact() throws {
        let model=try ToothFixtures.model(), policy=try ToothFixtures.policy(), initial=try ToothFixtures.initial(model)
        let service:any ToothContactEvolving=ReferenceToothContactEvolution(model:model)
        var work=try ToothFixtures.work()
        let saved=try service.advance(accepted:initial,to:0.04,timeStep:0.001,policy:policy,work:&work).accepted
        let first=try service.advance(accepted:saved,to:0.08,timeStep:0.001,policy:policy,work:&work).accepted
        let fresh:any ToothContactEvolving=ReferenceToothContactEvolution(model:try ToothFixtures.model())
        var replayWork=try ToothFixtures.work()
        let replay=try fresh.advance(accepted:saved,to:0.08,timeStep:0.001,policy:policy,work:&replayWork).accepted
        #expect(first.physical == replay.physical && first.histories == replay.histories)
        #expect(first.accumulatedDriveWork == replay.accumulatedDriveWork && first.originalEnergyDefect == replay.originalEnergyDefect)
        #expect(saved.physical.time == 0.04 && saved.histories.allSatisfy{$0.timeSeconds == 0.04})
    }
}
