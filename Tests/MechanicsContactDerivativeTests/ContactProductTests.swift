import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ContactProductTests {
    @Test(arguments:[0,1,2]) func normalProductsUseOriginalIndependentEquations(_ mode: Int) throws {
        let law: ContactNormalLaw
        if mode == 0 { law = .linear(stiffness:1000,damping:20,maximumPenetration:0.5,maximumNormalSpeed:100) }
        else if mode == 1 { law = .hertz(coefficient:1000,effectiveRadius:1,maximumPenetration:0.5,maximumNormalSpeed:100) }
        else { law = .huntCrossley(coefficient:1000,alpha:0.4,effectiveRadius:1,maximumPenetration:0.5,maximumNormalSpeed:100) }
        let pair=try ContactDerivativeFixtures.pair(law), input=try ContactDerivativeFixtures.input()
        let history=try ContactDerivativeFixtures.history(pair,input:input), policy=try ContactDerivativeFixtures.policy()
        let direction=try ContactDirection(separation:-0.003,relativeVelocity:Vector3(0,0,0.4))
        var work=try ContactDerivativeFixtures.work(); let service: any ContactDifferentiating=ExactContactDifferentiator()
        let result=try service.contact(input:input,pair:pair,accepted:history,direction:direction,policy:policy,work:&work)
        let delta=0.02, vn = -0.1, dd=0.003, dv=0.4
        let elastic=mode == 0 ? 1000*delta : 1000*delta*delta.squareRoot()
        let de=mode == 0 ? 1000*dd : 1500*delta.squareRoot()*dd
        let force=mode == 0 ? elastic-20*vn : mode == 1 ? elastic : elastic*(1-0.4*vn)
        let df=mode == 0 ? de-20*dv : mode == 1 ? de : de*(1-0.4*vn)-elastic*0.4*dv
        #expect(ContactDerivativeFixtures.close(result.compressiveNormalForce,df))
        #expect(ContactDerivativeFixtures.close(result.normalStoredEnergy,elastic*dd))
        #expect(ContactDerivativeFixtures.close(result.normalDissipationPower,(de-df)*vn+(elastic-force)*dv))
        #expect(ContactDerivativeFixtures.close(result.relativeMechanicalPower,df*vn+force*dv))
        #expect(result.validity.branch == .compressive)
        #expect(result.source.identity == input.identity && result.acceptedHistory == history)
        #expect(result.primal.trialHistory.sequence == history.sequence+1 && work.operations > 8000)
    }
    @Test func clippedUnloadingRetainsElasticEnergyDerivative() throws {
        let pair=try ContactDerivativeFixtures.pair(), input=try ContactDerivativeFixtures.input(vn:2)
        let history=try ContactDerivativeFixtures.history(pair,input:input), policy=try ContactDerivativeFixtures.policy()
        let direction=try ContactDirection(separation:-0.003,relativeVelocity:Vector3(0,0,0.4))
        var work=try ContactDerivativeFixtures.work()
        let result=try ExactContactDifferentiator().contact(input:input,pair:pair,accepted:history,direction:direction,policy:policy,work:&work)
        #expect(result.validity.branch == .clipped && result.compressiveNormalForce == 0)
        #expect(ContactDerivativeFixtures.close(result.normalStoredEnergy,0.06))
        #expect(ContactDerivativeFixtures.close(result.normalDissipationPower,14))
        #expect(result.relativeMechanicalPower == 0)
    }
    @Test func rotatedBasisAndSeparatedBranchArePhysical() throws {
        let rotation=try UnitQuaternion(axis:.unitY,angle:.pi/2)
        let pair=try ContactDerivativeFixtures.pair(), input=try ContactDerivativeFixtures.input(rotation:rotation)
        let history=try ContactDerivativeFixtures.history(pair,input:input), policy=try ContactDerivativeFixtures.policy()
        let direction=try ContactDirection(separation:0.001,relativeVelocity:input.basis.normal.scaled(by:0.2))
        var work=try ContactDerivativeFixtures.work()
        let result=try ExactContactDifferentiator().contact(input:input,pair:pair,accepted:history,direction:direction,policy:policy,work:&work)
        #expect(ContactDerivativeFixtures.close(result.forceOnB.x,-5))
        #expect(abs(result.forceOnB.y) < 1e-12 && abs(result.forceOnB.z) < 1e-12)
        let open=try ContactDerivativeFixtures.input(s:0.02), oh=try ContactDerivativeFixtures.history(pair,input:open)
        let separated=try ExactContactDifferentiator().contact(input:open,pair:pair,accepted:oh,direction:direction,policy:policy,work:&work)
        #expect(separated.validity.branch == .separated && separated.normalStoredEnergy == 0 && separated.forceOnB == .zero)
    }
    @Test func actualPrimalRefinementConvergesToHertzProduct() throws {
        let pair=try ContactDerivativeFixtures.pair(.hertz(coefficient:1000,effectiveRadius:1,maximumPenetration:0.5,maximumNormalSpeed:100))
        let input=try ContactDerivativeFixtures.input(), history=try ContactDerivativeFixtures.history(pair,input:input)
        let direction=try ContactDirection(separation:-0.003,relativeVelocity:.zero), policy=try ContactDerivativeFixtures.policy()
        var work=try ContactDerivativeFixtures.work()
        let result=try ExactContactDifferentiator().contact(input:input,pair:pair,accepted:history,direction:direction,policy:policy,work:&work)
        var errors:[Double]=[]
        for h in [0.02,0.01,0.005] {
            let perturbed=try ContactDerivativeFixtures.input(s:input.separation+h*direction.separation)
            var primalWork=try ContactDerivativeFixtures.primalWork()
            let primal=try CompliantContactEvaluator().evaluate(input:perturbed,pair:pair,accepted:history,policy:policy.acceptance,work:&primalWork)
            errors.append(abs((primal.compressiveNormalForce-result.primal.compressiveNormalForce)/h-result.compressiveNormalForce))
        }
        #expect(errors[1] < errors[0]*0.51 && errors[2] < errors[1]*0.51)
    }
    @Test(arguments:[0.5,2.0]) func impactProductsPreserveOriginalEnergyPartition(_ speed: Double) throws {
        let pair=try ContactDerivativeFixtures.pair(.hertz(coefficient:1000,effectiveRadius:1,maximumPenetration:0.5,maximumNormalSpeed:100),loss:.separateImpact(restitution:0.6,thresholdSpeed:1))
        let direction=try ContactImpactDirection(approachSpeed:0.3,incomingNormalEnergy:-0.5), policy=try ContactDerivativeFixtures.policy()
        var work=try ContactDerivativeFixtures.work(); let service: any ContactDifferentiating=ExactContactDifferentiator()
        let result=try service.impact(pair:pair,approachSpeed:speed,incomingNormalEnergy:4,direction:direction,policy:policy,work:&work)
        let e=speed < 1 ? 0.0 : 0.6
        #expect(ContactDerivativeFixtures.close(result.reboundSpeed,e*0.3))
        #expect(ContactDerivativeFixtures.close(result.retainedNormalEnergy,e*e*(-0.5)))
        #expect(ContactDerivativeFixtures.close(result.lostNormalEnergy,(1-e*e)*(-0.5)))
        #expect(ContactDerivativeFixtures.close(result.retainedNormalEnergy+result.lostNormalEnergy,-0.5))
        #expect(result.effectiveRestitution == 0 && result.primal.effectiveRestitution == e)
    }
}
