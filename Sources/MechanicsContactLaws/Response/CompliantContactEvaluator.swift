import MechanicsCore
import MechanicsModel
public struct CompliantContactEvaluator: ContactLawEvaluating, Sendable {
    public init() {}
    public func initialHistory(identity: ContactIdentity, pair: ContactLawPair, timeSeconds: Double,
                               work: inout ContactWork) throws(ContactLawError) -> ContactHistory {
        try work.consume(operations:32,scalarStorage:96,records:1)
        try contactAccountIdentity(identity,work:&work); try contactAccountPair(pair,work:&work)
        guard timeSeconds.isFinite, timeSeconds >= 0 else { throw .invalidInput }
        try work.checkCancellation()
        return ContactHistory(identity:identity,pair:pair,sequence:0,timeSeconds:timeSeconds,
            firstBristleDisplacement:0,secondBristleDisplacement:0,cumulativeTangentialDissipation:0)
    }
    public func evaluate(input: ContactInput, pair: ContactLawPair, accepted: ContactHistory,
                         policy: ContactAcceptancePolicy, work: inout ContactWork) throws(ContactLawError) -> ContactResponse {
        try work.consume(operations:4096,scalarStorage:256,records:1)
        try contactAccountIdentity(input.identity,work:&work); try contactAccountIdentity(accepted.identity,work:&work)
        try contactAccountPair(pair,work:&work); try contactAccountPair(accepted.pair,work:&work)
        guard input.identity == accepted.identity, pair == accepted.pair,
              input.startTimeSeconds == accepted.timeSeconds else { throw .staleHistory }
        let (sequence,overflow)=accepted.sequence.addingReportingOverflow(1)
        guard !overflow else { throw .sequenceOverflow }
        let time=try contactFinite(input.startTimeSeconds+input.timeStepSeconds)
        guard time > accepted.timeSeconds else { throw .invalidInput }
        let vn=try dot(input.basis.normal,input.relativeVelocity)
        let v1=try dot(input.basis.firstTangent,input.relativeVelocity)
        let v2=try dot(input.basis.secondTangent,input.relativeVelocity)
        let w1=try dot(input.basis.firstTangent,input.relativeAngularVelocity)
        let w2=try dot(input.basis.secondTangent,input.relativeAngularVelocity)
        let wn=try dot(input.basis.normal,input.relativeAngularVelocity)
        let normal=try normalResponse(pair.parameters.normal,separation:input.separation,velocity:vn)
        let fn=normal.0
        var f1=0.0,f2=0.0,z1=0.0,z2=0.0,ut=0.0,diss=0.0,utilization=0.0,energyResidual=0.0
        let regime:ContactFrictionRegime
        switch pair.parameters.friction {
        case .none:
            regime = .disabled
        case .elasticCoulomb(let friction):
            let kt=friction.tangentialStiffness
            let old1=accepted.firstBristleDisplacement,old2=accepted.secondBristleDisplacement
            let oldEnergy=try contactFinite(0.5*kt*squared(old1,old2))
            if fn == 0 {
                diss=oldEnergy; regime = .released
            } else {
                let dx1=try contactFinite(input.timeStepSeconds*v1),dx2=try contactFinite(input.timeStepSeconds*v2)
                let trial1=try contactFinite(old1+dx1),trial2=try contactFinite(old2+dx2)
                let traction1=try contactFinite(kt*trial1),traction2=try contactFinite(kt*trial2)
                let staticNorm=try ellipse(traction1,traction2,first:friction.staticFirst,second:friction.staticSecond,load:fn)
                let factor:Double,mu1:Double,mu2:Double
                if staticNorm <= 1 {
                    factor=1; mu1=friction.staticFirst; mu2=friction.staticSecond; regime = .sticking
                } else {
                    let speed=try magnitude(v1,v2)
                    let denominator=try contactFinite(friction.transitionSpeed+speed)
                    let blend=friction.transitionSpeed/denominator
                    mu1=try contactFinite(friction.dynamicFirst+(friction.staticFirst-friction.dynamicFirst)*blend)
                    mu2=try contactFinite(friction.dynamicSecond+(friction.staticSecond-friction.dynamicSecond)*blend)
                    let dynamicNorm=try ellipse(traction1,traction2,first:mu1,second:mu2,load:fn)
                    guard dynamicNorm > 1 else { throw .arithmeticFailure }
                    factor=1/dynamicNorm; regime = .sliding
                }
                z1=try contactFinite(factor*trial1); z2=try contactFinite(factor*trial2)
                f1=try contactFinite(-kt*z1); f2=try contactFinite(-kt*z2)
                ut=try contactFinite(0.5*kt*squared(z1,z2))
                // This nonnegative identity is independently checked against original traction work below.
                diss=try contactFinite(0.5*kt*(squared(old1-factor*trial1,old2-factor*trial2)+2*factor*(1-factor)*squared(trial1,trial2)))
                let workEnergy=try contactFinite(-f1*dx1-f2*dx2)
                let directD=try contactFinite(workEnergy-(ut-oldEnergy))
                energyResidual=abs(diss-directD)
                let threshold=try contactFinite(policy.absoluteEnergyTolerance+policy.relativeTolerance*max(policy.referenceEnergy,max(abs(workEnergy),max(ut,oldEnergy))))
                guard energyResidual <= threshold else { throw .energyResidual(value:energyResidual,threshold:threshold) }
                utilization=try ellipse(f1,f2,first:mu1,second:mu2,load:fn)
                let coneThreshold=try contactFinite(1+policy.coneTolerance)
                guard utilization <= coneThreshold else { throw .coneResidual(value:utilization,threshold:coneThreshold) }
            }
        }
        guard diss >= 0 else { throw .arithmeticFailure }
        let resistance=pair.parameters.resistance
        let rollingSpeed=try magnitude(w1,w2)
        let regularization=resistance.angularRegularization
        let rollingDenominator=try magnitude(rollingSpeed,regularization)
        let spinningDenominator=try magnitude(wn,regularization)
        let rollingLimit=try contactFinite(resistance.rollingCoefficient*fn*pair.parameters.resistanceRadius)
        let spinningLimit=try contactFinite(resistance.spinningCoefficient*fn*pair.parameters.resistanceRadius)
        let t1=try contactFinite(-rollingLimit*(w1/rollingDenominator))
        let t2=try contactFinite(-rollingLimit*(w2/rollingDenominator))
        let tn=try contactFinite(-spinningLimit*(wn/spinningDenominator))
        let resistanceD=try contactFinite(-t1*w1-t2*w2-tn*wn)
        guard resistanceD >= 0 else { throw .arithmeticFailure }
        let cohesion=try cohesiveResponse(pair.parameters.cohesion,separation:input.separation)
        let totalNormal=try contactFinite(fn+cohesion.0)
        let force=try axes(input.basis,normal:totalNormal,first:f1,second:f2)
        let couple=try axes(input.basis,normal:tn,first:t1,second:t2)
        let globalPower=try contactFinite(dot(force,input.relativeVelocity)+dot(couple,input.relativeAngularVelocity))
        let localPower=try contactFinite(totalNormal*vn+f1*v1+f2*v2+t1*w1+t2*w2+tn*wn)
        let powerResidual=abs(globalPower-localPower)
        let powerThreshold=try contactFinite(policy.absolutePowerTolerance+policy.relativeTolerance*max(policy.referencePower,max(abs(globalPower),abs(localPower))))
        guard powerResidual <= powerThreshold else { throw .powerResidual(value:powerResidual,threshold:powerThreshold) }
        let history=ContactHistory(identity:input.identity,pair:pair,sequence:sequence,timeSeconds:time,
            firstBristleDisplacement:z1,secondBristleDisplacement:z2,
            cumulativeTangentialDissipation:try contactFinite(accepted.cumulativeTangentialDissipation+diss))
        try work.checkCancellation()
        return ContactResponse(forceOnB:force,coupleOnB:couple,compressiveNormalForce:fn,cohesiveNormalForce:cohesion.0,
            tangentialForceFirst:f1,tangentialForceSecond:f2,normalForcePenetrationDerivative:normal.2,
            normalForceVelocityDerivative:normal.3,normalStoredEnergy:normal.1,tangentialStoredEnergy:ut,
            cohesivePotentialEnergy:cohesion.1,completeCohesiveSeparationWork:cohesion.2,
            normalDissipationPower:normal.4,resistanceDissipationPower:resistanceD,tangentialDissipationEnergy:diss,
            relativeMechanicalPower:globalPower,frictionConeUtilization:utilization,frictionRegime:regime,
            originalTangentialEnergyResidual:energyResidual,originalPowerResidual:powerResidual,
            acceptedHistorySequence:accepted.sequence,trialHistory:history)
    }
    private func normalResponse(_ law:ContactNormalLaw,separation:Double,velocity:Double) throws(ContactLawError) -> (Double,Double,Double,Double,Double) {
        let p:Double,v:Double,k:Double,d:Double,isLinear:Bool,isHC:Bool
        switch law {
        case .linear(let stiffness,let damping,let penetration,let speed): k=stiffness; d=damping; p=penetration; v=speed; isLinear=true; isHC=false
        case .hertz(let coefficient,_,let penetration,let speed): k=coefficient; d=0; p=penetration; v=speed; isLinear=false; isHC=false
        case .huntCrossley(let coefficient,let alpha,_,let penetration,let speed): k=coefficient; d=alpha; p=penetration; v=speed; isLinear=false; isHC=true
        }
        let delta=max(-separation,0)
        guard delta <= p, abs(velocity) <= v else { throw .normalDomain }
        if separation >= 0 { return (0,0,0,0,0) }
        let fe=try contactFinite(isLinear ? k*delta : k*delta*delta.squareRoot())
        let derivative=try contactFinite(isLinear ? k : 1.5*k*delta.squareRoot())
        let energy=try contactFinite((isLinear ? 0.5 : 0.4)*fe*delta)
        let unclipped=try contactFinite(isHC ? fe*(1-d*velocity) : fe-d*velocity)
        let force=max(unclipped,0)
        let derivativeP=unclipped > 0 ? try contactFinite(isHC ? derivative*(1-d*velocity) : derivative) : 0
        let derivativeV=unclipped > 0 ? try contactFinite(isHC ? -fe*d : -d) : 0
        let loss=try contactFinite((fe-force)*velocity)
        guard loss >= 0 else { throw .arithmeticFailure }
        return (force,energy,derivativeP,derivativeV,loss)
    }
    private func cohesiveResponse(_ law:ContactCohesionLaw,separation:Double) throws(ContactLawError) -> (Double,Double,Double) {
        switch law {
        case .none: return (0,0,0)
        case .reversibleLinear(let limit,let range):
            let openingWork=try contactFinite(0.5*limit*range)
            if separation < 0 { return (0,-openingWork,openingWork) }
            if separation >= range { return (0,0,openingWork) }
            let remainder=1-separation/range
            return (try contactFinite(-limit*remainder),try contactFinite(-openingWork*remainder*remainder),openingWork)
        }
    }
    private func squared(_ x:Double,_ y:Double) throws(ContactLawError) -> Double { try contactFinite(x*x+y*y) }
    private func magnitude(_ x:Double,_ y:Double) throws(ContactLawError) -> Double {
        try contactCore { () throws(CoreError) in try Vector3(x,y,0).magnitude() }
    }
    private func dot(_ x:Vector3,_ y:Vector3) throws(ContactLawError) -> Double {
        try contactCore { () throws(CoreError) in try x.dot(y) }
    }
    private func ellipse(_ x:Double,_ y:Double,first:Double,second:Double,load:Double) throws(ContactLawError) -> Double {
        let a=try contactFinite(first*load),b=try contactFinite(second*load)
        guard a > 0, b > 0 else { throw .arithmeticFailure }
        return try magnitude(contactFinite(x/a),contactFinite(y/b))
    }
    private func axes(_ basis:ContactBasis,normal:Double,first:Double,second:Double) throws(ContactLawError) -> Vector3 {
        try contactCore { () throws(CoreError) in
            try basis.normal.scaled(by:normal).adding(basis.firstTangent.scaled(by:first)).adding(basis.secondTangent.scaled(by:second))
        }
    }
}
