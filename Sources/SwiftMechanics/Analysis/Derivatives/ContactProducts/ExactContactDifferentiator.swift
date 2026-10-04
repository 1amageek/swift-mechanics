public struct ExactContactDifferentiator: ContactDifferentiating, Sendable {
    private let laws: any ContactLawEvaluating
    private let impacts: any ContactImpactPredicting
    public init(laws: any ContactLawEvaluating = CompliantContactEvaluator(),
                impacts: any ContactImpactPredicting = ThresholdRestitutionPredictor()) {
        self.laws=laws; self.impacts=impacts
    }
    @inline(never)
    public func contact(input: ContactInput, pair: ContactLawPair, accepted: ContactHistory,
                        direction: ContactDirection, policy: ContactDerivativePolicy,
                        work: inout ContactDerivativeWork) throws(ContactDerivativeError) -> ContactResponseTangent {
        try ContactProductArithmetic.metadata(pair,identity:input.identity,policy:policy,work:&work)
        try ContactProductArithmetic.metadata(accepted.pair,identity:accepted.identity,policy:policy,work:&work)
        guard input.identity == accepted.identity, pair == accepted.pair, input.startTimeSeconds == accepted.timeSeconds else { throw .law(.staleHistory) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Friction, cohesion and resistance products are not implemented.
        // ContactProducts rejects these actual calls; original full-law smooth/nonsmooth acceptance is required before success.
        guard case .none=pair.parameters.friction, case .none=pair.parameters.cohesion,
              pair.parameters.resistance.rollingCoefficient == 0, pair.parameters.resistance.spinningCoefficient == 0 else { throw .unsupportedDomain }
        try ContactProductArithmetic.charge(512,&work)
        let vn=try ContactProductArithmetic.core { () throws(CoreError) in try input.basis.normal.dot(input.relativeVelocity) }
        let dv=try ContactProductArithmetic.core { () throws(CoreError) in try input.basis.normal.dot(direction.relativeVelocity) }
        let validity=try ContactNormalProduct.admit(pair.parameters.normal,separation:input.separation,velocity:vn,policy:policy)
        let primal=try evaluated(input,pair:pair,accepted:accepted,policy:policy,work:&work)
        let product=try ContactNormalProduct.compute(pair.parameters.normal,separation:input.separation,velocity:vn,
            separationDirection:direction.separation,velocityDirection:dv,branch:validity.branch)
        let force=try ContactProductArithmetic.core { () throws(CoreError) in try input.basis.normal.scaled(by:product.force) }
        try ContactProductArithmetic.check(policy)
        return ContactResponseTangent(source:input,pair:pair,acceptedHistory:accepted,primal:primal,direction:direction,
            validity:validity,forceOnB:force,compressiveNormalForce:product.force,normalStoredEnergy:product.energy,
            normalDissipationPower:product.dissipation,relativeMechanicalPower:product.power)
    }
    @inline(never)
    private func evaluated(_ input: ContactInput, pair: ContactLawPair, accepted: ContactHistory,
                           policy: ContactDerivativePolicy, work: inout ContactDerivativeWork) throws(ContactDerivativeError) -> ContactResponse {
        let result=try ContactProductArithmetic.supplier(policy,work:&work) { (local: inout ContactWork) throws(ContactLawError) in
            try laws.evaluate(input:input,pair:pair,accepted:accepted,policy:policy.acceptance,work:&local)
        }
        let original=try ContactProductArithmetic.supplier(policy,work:&work) { (local: inout ContactWork) throws(ContactLawError) in
            try CompliantContactEvaluator().evaluate(input:input,pair:pair,accepted:accepted,policy:policy.acceptance,work:&local)
        }
        try ContactProductArithmetic.charge(256,&work)
        guard result.trialHistory == original.trialHistory, result.acceptedHistorySequence == original.acceptedHistorySequence,
              result.frictionRegime == original.frictionRegime else { throw .primalMismatch }
        let a=[result.forceOnB.x,result.forceOnB.y,result.forceOnB.z,result.coupleOnB.x,result.coupleOnB.y,result.coupleOnB.z,
            result.compressiveNormalForce,result.cohesiveNormalForce,result.tangentialForceFirst,result.tangentialForceSecond,
            result.normalForcePenetrationDerivative,result.normalForceVelocityDerivative,result.normalStoredEnergy,
            result.tangentialStoredEnergy,result.cohesivePotentialEnergy,result.completeCohesiveSeparationWork,
            result.normalDissipationPower,result.resistanceDissipationPower,result.tangentialDissipationEnergy,
            result.relativeMechanicalPower,result.frictionConeUtilization,result.originalTangentialEnergyResidual,result.originalPowerResidual]
        let b=[original.forceOnB.x,original.forceOnB.y,original.forceOnB.z,original.coupleOnB.x,original.coupleOnB.y,original.coupleOnB.z,
            original.compressiveNormalForce,original.cohesiveNormalForce,original.tangentialForceFirst,original.tangentialForceSecond,
            original.normalForcePenetrationDerivative,original.normalForceVelocityDerivative,original.normalStoredEnergy,
            original.tangentialStoredEnergy,original.cohesivePotentialEnergy,original.completeCohesiveSeparationWork,
            original.normalDissipationPower,original.resistanceDissipationPower,original.tangentialDissipationEnergy,
            original.relativeMechanicalPower,original.frictionConeUtilization,original.originalTangentialEnergyResidual,original.originalPowerResidual]
        for i in a.indices { try ContactProductArithmetic.equal(a[i],b[i],policy) }
        return result
    }
    @inline(never)
    public func impact(pair: ContactLawPair, approachSpeed: Double, incomingNormalEnergy: Double,
                       direction: ContactImpactDirection, policy: ContactDerivativePolicy,
                       work: inout ContactDerivativeWork) throws(ContactDerivativeError) -> ContactImpactTangent {
        try ContactProductArithmetic.metadata(pair,identity:nil,policy:policy,work:&work)
        guard approachSpeed.isFinite, approachSpeed > 0, incomingNormalEnergy.isFinite, incomingNormalEnergy > 0 else { throw .invalidInput }
        guard case .separateImpact(let e,let threshold)=pair.lossPolicy else { throw .law(.incompatibleLossPolicy) }
        try ContactProductArithmetic.charge(128,&work)
        let lo=try ContactProductArithmetic.finite(approachSpeed-policy.normalSpeedRadius)
        let hi=try ContactProductArithmetic.finite(approachSpeed+policy.normalSpeedRadius)
        guard lo > 0 else { throw .outsideDomain }
        guard hi < threshold || lo > threshold else { throw .nonsmoothBoundary }
        let primal=try ContactProductArithmetic.supplier(policy,work:&work) { (local: inout ContactWork) throws(ContactLawError) in
            try impacts.predict(pair:pair,approachSpeed:approachSpeed,incomingNormalEnergy:incomingNormalEnergy,work:&local)
        }
        let original=try ContactProductArithmetic.supplier(policy,work:&work) { (local: inout ContactWork) throws(ContactLawError) in
            try ThresholdRestitutionPredictor().predict(pair:pair,approachSpeed:approachSpeed,incomingNormalEnergy:incomingNormalEnergy,work:&local)
        }
        try ContactProductArithmetic.equal(primal.effectiveRestitution,original.effectiveRestitution,policy)
        try ContactProductArithmetic.equal(primal.reboundSpeed,original.reboundSpeed,policy)
        try ContactProductArithmetic.equal(primal.retainedNormalEnergy,original.retainedNormalEnergy,policy)
        try ContactProductArithmetic.equal(primal.lostNormalEnergy,original.lostNormalEnergy,policy)
        let active=approachSpeed < threshold ? 0 : e
        let rebound=try ContactProductArithmetic.finite(active*direction.approachSpeed)
        let retained=try ContactProductArithmetic.finite(active*active*direction.incomingNormalEnergy)
        let lost=try ContactProductArithmetic.finite((1-active*active)*direction.incomingNormalEnergy)
        try ContactProductArithmetic.check(policy)
        return ContactImpactTangent(pair:pair,approachSpeed:approachSpeed,incomingNormalEnergy:incomingNormalEnergy,direction:direction,
            primal:primal,minimumApproachSpeed:lo,maximumApproachSpeed:hi,effectiveRestitution:0,reboundSpeed:rebound,
            retainedNormalEnergy:retained,lostNormalEnergy:lost)
    }
}
