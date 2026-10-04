public struct CompliantContactEvaluator: ContactLawEvaluating, Sendable {
    public init() {}
    public func initialHistory(identity: ContactIdentity, pair: ContactLawPair, timeSeconds: Double,
                               work: inout ContactWork) throws(ContactLawError) -> ContactHistory {
        try work.consume(operations:32,scalarStorage:96+identity.materialSiteScalarStorage,records:1)
        try contactAccountIdentity(identity,work:&work); try contactAccountPair(pair,work:&work)
        guard timeSeconds.isFinite, timeSeconds >= 0 else { throw .invalidInput }
        try work.checkCancellation()
        return ContactHistory(identity:identity,pair:pair,sequence:0,timeSeconds:timeSeconds,
            firstBristleDisplacement:0,secondBristleDisplacement:0,cumulativeTangentialDissipation:0)
    }
    public func evaluate(input: ContactInput, pair: ContactLawPair, accepted: ContactHistory,
                         policy: ContactAcceptancePolicy, work: inout ContactWork) throws(ContactLawError) -> ContactResponse {
        try work.consume(operations:4096,scalarStorage:256+input.identity.materialSiteScalarStorage+accepted.identity.materialSiteScalarStorage,records:1)
        try contactAccountIdentity(input.identity,work:&work); try contactAccountIdentity(accepted.identity,work:&work)
        try contactAccountPair(pair,work:&work); try contactAccountPair(accepted.pair,work:&work)
        guard input.identity == accepted.identity, pair == accepted.pair,
              input.startTimeSeconds == accepted.timeSeconds else { throw .staleHistory }
        let (sequence,overflow)=accepted.sequence.addingReportingOverflow(1)
        guard !overflow else { throw .sequenceOverflow }
        let time=try contactFinite(input.startTimeSeconds+input.timeStepSeconds)
        guard time > accepted.timeSeconds else { throw .invalidInput }
        let vn=try ContactConstitutiveKernels.dot(input.basis.normal,input.relativeVelocity)
        let v1=try ContactConstitutiveKernels.dot(input.basis.firstTangent,input.relativeVelocity)
        let v2=try ContactConstitutiveKernels.dot(input.basis.secondTangent,input.relativeVelocity)
        let w1=try ContactConstitutiveKernels.dot(input.basis.firstTangent,input.relativeAngularVelocity)
        let w2=try ContactConstitutiveKernels.dot(input.basis.secondTangent,input.relativeAngularVelocity)
        let wn=try ContactConstitutiveKernels.dot(input.basis.normal,input.relativeAngularVelocity)
        let normal=try ContactConstitutiveKernels.normalResponse(pair.parameters.normal,separation:input.separation,velocity:vn)
        let fn=normal.0
        var f1=0.0,f2=0.0,z1=0.0,z2=0.0,ut=0.0,diss=0.0,utilization=0.0,energyResidual=0.0
        let regime:ContactFrictionRegime
        switch pair.parameters.friction {
        case .none:
            regime = .disabled
        case .elasticCoulomb(let friction):
            let kt=friction.tangentialStiffness
            let old1=accepted.firstBristleDisplacement,old2=accepted.secondBristleDisplacement
            let oldEnergy=try contactFinite(0.5*kt*ContactConstitutiveKernels.squared(old1,old2))
            if fn == 0 {
                diss=oldEnergy; regime = .released
            } else {
                let dx1=try contactFinite(input.timeStepSeconds*v1),dx2=try contactFinite(input.timeStepSeconds*v2)
                let trial1=try contactFinite(old1+dx1),trial2=try contactFinite(old2+dx2)
                let traction1=try contactFinite(kt*trial1),traction2=try contactFinite(kt*trial2)
                let staticNorm=try ContactConstitutiveKernels.ellipse(traction1,traction2,first:friction.staticFirst,second:friction.staticSecond,load:fn)
                let factor:Double,mu1:Double,mu2:Double
                if staticNorm <= 1 {
                    factor=1; mu1=friction.staticFirst; mu2=friction.staticSecond; regime = .sticking
                } else {
                    let speed=try ContactConstitutiveKernels.magnitude(v1,v2)
                    let denominator=try contactFinite(friction.transitionSpeed+speed)
                    let blend=friction.transitionSpeed/denominator
                    mu1=try contactFinite(friction.dynamicFirst+(friction.staticFirst-friction.dynamicFirst)*blend)
                    mu2=try contactFinite(friction.dynamicSecond+(friction.staticSecond-friction.dynamicSecond)*blend)
                    let dynamicNorm=try ContactConstitutiveKernels.ellipse(traction1,traction2,first:mu1,second:mu2,load:fn)
                    guard dynamicNorm > 1 else { throw .arithmeticFailure }
                    factor=1/dynamicNorm; regime = .sliding
                }
                z1=try contactFinite(factor*trial1); z2=try contactFinite(factor*trial2)
                f1=try contactFinite(-kt*z1); f2=try contactFinite(-kt*z2)
                ut=try contactFinite(0.5*kt*ContactConstitutiveKernels.squared(z1,z2))
                // This nonnegative identity is independently checked against original traction work below.
                diss=try contactFinite(0.5*kt*(ContactConstitutiveKernels.squared(old1-factor*trial1,old2-factor*trial2)+2*factor*(1-factor)*ContactConstitutiveKernels.squared(trial1,trial2)))
                let workEnergy=try contactFinite(-f1*dx1-f2*dx2)
                let directD=try contactFinite(workEnergy-(ut-oldEnergy))
                energyResidual=abs(diss-directD)
                let threshold=try contactFinite(policy.absoluteEnergyTolerance+policy.relativeTolerance*max(policy.referenceEnergy,max(abs(workEnergy),max(ut,oldEnergy))))
                guard energyResidual <= threshold else { throw .energyResidual(value:energyResidual,threshold:threshold) }
                utilization=try ContactConstitutiveKernels.ellipse(f1,f2,first:mu1,second:mu2,load:fn)
                let coneThreshold=try contactFinite(1+policy.coneTolerance)
                guard utilization <= coneThreshold else { throw .coneResidual(value:utilization,threshold:coneThreshold) }
            }
        }
        guard diss >= 0 else { throw .arithmeticFailure }
        let resistance=try ContactConstitutiveKernels.resistanceResponse(pair.parameters.resistance,load:fn,radius:pair.parameters.resistanceRadius,first:w1,second:w2,normal:wn)
        let t1=resistance.0,t2=resistance.1,tn=resistance.2,resistanceD=resistance.3
        let cohesion=try ContactConstitutiveKernels.cohesiveResponse(pair.parameters.cohesion,separation:input.separation)
        let totalNormal=try contactFinite(fn+cohesion.0)
        let force=try ContactConstitutiveKernels.axes(input.basis,normal:totalNormal,first:f1,second:f2)
        let couple=try ContactConstitutiveKernels.axes(input.basis,normal:tn,first:t1,second:t2)
        let globalPower=try contactFinite(ContactConstitutiveKernels.dot(force,input.relativeVelocity)+ContactConstitutiveKernels.dot(couple,input.relativeAngularVelocity))
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
}
