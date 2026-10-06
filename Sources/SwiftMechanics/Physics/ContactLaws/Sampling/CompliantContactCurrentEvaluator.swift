public struct CompliantContactCurrentEvaluator: ContactCurrentEvaluating, Sendable {
    public init() {}

    public func sample(input: ContactCurrentInput, pair: ContactLawPair, accepted: ContactHistory,
                       policy: ContactAcceptancePolicy, work: inout ContactWork) throws(ContactCurrentError) -> ContactCurrentResponse {
        try contactCurrentLaw { () throws(ContactLawError) in
            try work.consume(operations:4096,scalarStorage:512+input.identity.materialSiteScalarStorage+accepted.identity.materialSiteScalarStorage,records:1)
            try contactAccountIdentity(input.identity,work:&work); try contactAccountIdentity(accepted.identity,work:&work)
            try contactAccountPair(pair,work:&work); try contactAccountPair(accepted.pair,work:&work)
            guard input.identity == accepted.identity, pair == accepted.pair,
                  input.timeSeconds == accepted.timeSeconds else { throw .staleHistory }
        }
        let motion=try localMotion(input)
        let normal=try contactCurrentLaw { () throws(ContactLawError) in
            try ContactConstitutiveKernels.normalResponse(pair.parameters.normal,separation:input.separation,velocity:motion.0)
        }
        let tangent=try elasticTraction(pair.parameters.friction,accepted:accepted,load:normal.0,policy:policy)
        let resistance=try contactCurrentLaw { () throws(ContactLawError) in
            try ContactConstitutiveKernels.resistanceResponse(pair.parameters.resistance,load:normal.0,
                radius:pair.parameters.resistanceRadius,first:motion.3,second:motion.4,normal:motion.5)
        }
        let cohesion=try contactCurrentLaw { () throws(ContactLawError) in
            try ContactConstitutiveKernels.cohesiveResponse(pair.parameters.cohesion,separation:input.separation)
        }
        let vectors=try contactCurrentLaw { () throws(ContactLawError) in
            let force=try ContactConstitutiveKernels.axes(input.basis,normal:contactFinite(normal.0+cohesion.0),first:tangent.0,second:tangent.1)
            let couple=try ContactConstitutiveKernels.axes(input.basis,normal:resistance.2,first:resistance.0,second:resistance.1)
            return (force,couple)
        }
        let power=try powerEvidence(input:input,force:vectors.0,couple:vectors.1,motion:motion,
            normal:normal.0,elastic:normal.5,cohesion:cohesion.0,first:tangent.0,second:tangent.1,
            rollingFirst:resistance.0,rollingSecond:resistance.1,spin:resistance.2,
            normalLoss:normal.4,resistanceLoss:resistance.3,policy:policy)
        let derivatives=try branchDerivatives(input:input,pair:pair,motion:motion,normalPenetration:normal.2,
            normalVelocity:normal.3,unclipped:normal.6,tangentDerivative:tangent.4,
            rollingDenominator:resistance.4,spinningDenominator:resistance.5,
            rollingLimit:resistance.6,spinningLimit:resistance.7)
        try contactCurrentLaw { () throws(ContactLawError) in try work.checkCancellation() }
        return ContactCurrentResponse(acceptedHistory:accepted,forceOnB:vectors.0,coupleOnB:vectors.1,
            compressiveNormalForce:normal.0,elasticNormalForce:normal.5,cohesiveNormalForce:cohesion.0,
            tangentialForceFirst:tangent.0,tangentialForceSecond:tangent.1,normalStoredEnergy:normal.1,
            tangentialStoredEnergy:tangent.2,cohesivePotentialEnergy:cohesion.1,completeCohesiveSeparationWork:cohesion.2,
            normalDissipationPower:normal.4,resistanceDissipationPower:resistance.3,relativeMechanicalPower:power.0,
            elasticPotentialRatePower:power.1,staticFrictionConeUtilization:tangent.3,
            originalPowerResidual:power.2,originalRatePowerResidual:power.3,derivatives:derivatives)
    }

    @inline(never)
    private func localMotion(_ input:ContactCurrentInput) throws(ContactCurrentError) -> (Double,Double,Double,Double,Double,Double) {
        try contactCurrentLaw { () throws(ContactLawError) in
            (try ContactConstitutiveKernels.dot(input.basis.normal,input.relativeVelocity),
             try ContactConstitutiveKernels.dot(input.basis.firstTangent,input.relativeVelocity),
             try ContactConstitutiveKernels.dot(input.basis.secondTangent,input.relativeVelocity),
             try ContactConstitutiveKernels.dot(input.basis.firstTangent,input.relativeAngularVelocity),
             try ContactConstitutiveKernels.dot(input.basis.secondTangent,input.relativeAngularVelocity),
             try ContactConstitutiveKernels.dot(input.basis.normal,input.relativeAngularVelocity))
        }
    }

    @inline(never)
    private func elasticTraction(_ law:ContactFrictionLaw,accepted:ContactHistory,load:Double,
                                 policy:ContactAcceptancePolicy) throws(ContactCurrentError) -> (Double,Double,Double,Double,Double) {
        let z1=accepted.firstBristleDisplacement,z2=accepted.secondBristleDisplacement
        switch law {
        case .none:
            guard z1 == 0, z2 == 0 else { throw .disabledFrictionBristles }
            return (0,0,0,0,0)
        case .elasticCoulomb(let friction):
            if load == 0 {
                guard z1 == 0, z2 == 0 else { throw .unloadedBristles }
                return (0,0,0,0,-friction.tangentialStiffness)
            }
            let response=try contactCurrentLaw { () throws(ContactLawError) in
                let kt=friction.tangentialStiffness
                let first=try contactFinite(-kt*z1),second=try contactFinite(-kt*z2)
                let energy=try contactFinite(0.5*kt*ContactConstitutiveKernels.squared(z1,z2))
                let utilization=try ContactConstitutiveKernels.ellipse(first,second,first:friction.staticFirst,second:friction.staticSecond,load:load)
                return (first,second,energy,utilization,-kt)
            }
            let threshold=try contactCurrentLaw { () throws(ContactLawError) in try contactFinite(1+policy.coneTolerance) }
            guard response.3 <= threshold else { throw .inadmissibleAcceptedTraction(utilization:response.3,threshold:threshold) }
            return response
        }
    }

    @inline(never)
    private func powerEvidence(input:ContactCurrentInput,force:Vector3,couple:Vector3,
        motion:(Double,Double,Double,Double,Double,Double),normal:Double,elastic:Double,cohesion:Double,
        first:Double,second:Double,rollingFirst:Double,rollingSecond:Double,spin:Double,
        normalLoss:Double,resistanceLoss:Double,policy:ContactAcceptancePolicy) throws(ContactCurrentError) -> (Double,Double,Double,Double) {
        let evidence=try contactCurrentLaw { () throws(ContactLawError) in
            let global=try contactFinite(ContactConstitutiveKernels.dot(force,input.relativeVelocity)+ContactConstitutiveKernels.dot(couple,input.relativeAngularVelocity))
            let local=try contactFinite((normal+cohesion)*motion.0+first*motion.1+second*motion.2+rollingFirst*motion.3+rollingSecond*motion.4+spin*motion.5)
            let rate=try contactFinite(-elastic*motion.0-cohesion*motion.0-first*motion.1-second*motion.2)
            let residual=abs(global-local)
            let threshold=try contactFinite(policy.absolutePowerTolerance+policy.relativeTolerance*max(policy.referencePower,max(abs(global),abs(local))))
            guard residual <= threshold else { throw .powerResidual(value:residual,threshold:threshold) }
            let rateResidual=abs(try contactFinite(global+rate+normalLoss+resistanceLoss))
            let rateScale=max(policy.referencePower,max(abs(global),max(abs(rate),max(normalLoss,resistanceLoss))))
            let rateThreshold=try contactFinite(policy.absolutePowerTolerance+policy.relativeTolerance*rateScale)
            return (global,rate,residual,rateResidual,rateThreshold)
        }
        guard evidence.3 <= evidence.4 else { throw .ratePowerResidual(value:evidence.3,threshold:evidence.4) }
        return (evidence.0,evidence.1,evidence.2,evidence.3)
    }

    @inline(never)
    private func branchDerivatives(input:ContactCurrentInput,pair:ContactLawPair,
        motion:(Double,Double,Double,Double,Double,Double),normalPenetration:Double,normalVelocity:Double,
        unclipped:Double,tangentDerivative:Double,rollingDenominator:Double,spinningDenominator:Double,
        rollingLimit:Double,spinningLimit:Double) throws(ContactCurrentError) -> ContactCurrentDerivatives {
        try contactCurrentLaw { () throws(ContactLawError) in
            let cohesionDerivative:Double,cohesionSmooth:Bool
            switch pair.parameters.cohesion {
            case .none: cohesionDerivative=0; cohesionSmooth=true
            case .reversibleLinear(let force,let range):
                cohesionDerivative=input.separation >= 0 && input.separation < range ? try contactFinite(force/range) : 0
                cohesionSmooth=input.separation != 0 && input.separation != range
            }
            let a=try contactFinite(motion.3/rollingDenominator),b=try contactFinite(motion.4/rollingDenominator)
            let c=try contactFinite(motion.5/spinningDenominator)
            let rollingFactor=try contactFinite(-rollingLimit/rollingDenominator)
            let spinningFactor=try contactFinite(-spinningLimit/spinningDenominator)
            // Stable normalized ratios avoid forming squared denominators.
            let r=try contactFinite(pair.parameters.resistance.angularRegularization/rollingDenominator)
            let sr=try contactFinite(pair.parameters.resistance.angularRegularization/spinningDenominator)
            let d11=try contactFinite(rollingFactor*(b*b+r*r)),d12=try contactFinite(-rollingFactor*a*b)
            let d22=try contactFinite(rollingFactor*(a*a+r*r)),dn=try contactFinite(spinningFactor*sr*sr)
            let resistance=pair.parameters.resistance,radius=pair.parameters.resistanceRadius
            let loadDerivative=try ContactConstitutiveKernels.axes(input.basis,
                normal:contactFinite(-resistance.spinningCoefficient*radius*c),
                first:contactFinite(-resistance.rollingCoefficient*radius*a),
                second:contactFinite(-resistance.rollingCoefficient*radius*b))
            let normalSmooth=input.separation > 0 || (input.separation < 0 && unclipped != 0)
            return ContactCurrentDerivatives(normalForcePenetrationDerivative:normalPenetration,
                normalForceVelocityDerivative:normalVelocity,normalIsDifferentiable:normalSmooth,
                cohesiveForceSeparationDerivative:cohesionDerivative,cohesionIsDifferentiable:cohesionSmooth,
                tangentialForceBristleDerivative:tangentDerivative,rollingFirstAngularDerivative:d11,
                rollingCrossAngularDerivative:d12,rollingSecondAngularDerivative:d22,
                spinningAngularDerivative:dn,coupleCompressiveLoadDerivative:loadDerivative)
        }
    }
}
