import MechanicsModel
public struct SeriesContactPairing: ContactMaterialPairing, Sendable {
    public init() {}
    public func combine(first a: ContactMaterial, second b: ContactMaterial, selection: ContactNormalSelection,
                        lossPolicy: ContactLossPolicy, resistanceRadius: Double, override: ContactPairOverride?,
                        work: inout ContactWork) throws(ContactLawError) -> ContactLawPair {
        try work.consume(operations:512,scalarStorage:128,records:1)
        try contactAccountKey(a.reference.id.key,work:&work); try contactAccountKey(b.reference.id.key,work:&work)
        if let override { try contactAccountKey(override.first.id.key,work:&work); try contactAccountKey(override.second.id.key,work:&work) }
        let parameters: ContactResolvedParameters
        let provenance: ContactPairProvenance
        if let override {
            guard override.first.id == a.reference.id, override.second.id == b.reference.id else { throw .invalidOverrideOrder }
            guard override.first == a.reference, override.second == b.reference else { throw .staleMaterial }
            parameters=override.parameters; provenance = .orderedCalibratedOverride(revision:override.revision)
        } else {
            let normal: ContactNormalLaw
            switch selection {
            case .linear(let p,let v):
                let c = a.normalDamping == 0 || b.normalDamping == 0 ? 0 : try series(a.normalDamping,b.normalDamping)
                normal = .linear(stiffness:try series(a.linearStiffness,b.linearStiffness),damping:c,maximumPenetration:p,maximumNormalSpeed:v)
            case .hertz(let r,let p,let v), .huntCrossley(let r,let p,let v):
                guard r.isFinite, r > 0 else { throw .invalidMaterial }
                let compliance = try contactFinite((1-a.poissonsRatio*a.poissonsRatio)/a.youngModulus+(1-b.poissonsRatio*b.poissonsRatio)/b.youngModulus)
                guard compliance > 0 else { throw .arithmeticFailure }
                let k = try contactFinite((4.0/3)/compliance*r.squareRoot())
                if case .hertz = selection { normal = .hertz(coefficient:k,effectiveRadius:r,maximumPenetration:p,maximumNormalSpeed:v) }
                else { normal = .huntCrossley(coefficient:k,alpha:try contactFinite(a.huntCrossleyAlpha/2+b.huntCrossleyAlpha/2),effectiveRadius:r,maximumPenetration:p,maximumNormalSpeed:v) }
            }
            let friction: ContactFrictionLaw
            switch (a.friction,b.friction) {
            case (.none,.none): friction = .none
            case (.elasticCoulomb(let x),.elasticCoulomb(let y)):
                friction = .elasticCoulomb(try ContactFrictionParameters(staticFirst:min(x.staticFirst,y.staticFirst),staticSecond:min(x.staticSecond,y.staticSecond),
                    dynamicFirst:min(x.dynamicFirst,y.dynamicFirst),dynamicSecond:min(x.dynamicSecond,y.dynamicSecond),
                    tangentialStiffness:series(x.tangentialStiffness,y.tangentialStiffness),transitionSpeed:contactFinite(x.transitionSpeed/2+y.transitionSpeed/2)))
            default: throw .incompatibleFriction
            }
            let resistance = try ContactResistanceParameters(rollingCoefficient:min(a.resistance.rollingCoefficient,b.resistance.rollingCoefficient),
                spinningCoefficient:min(a.resistance.spinningCoefficient,b.resistance.spinningCoefficient),angularRegularization:contactFinite(a.resistance.angularRegularization/2+b.resistance.angularRegularization/2))
            let cohesion: ContactCohesionLaw
            switch (a.cohesion,b.cohesion) {
            case (.reversibleLinear(let x,let r),.reversibleLinear(let y,let s)): cohesion = .reversibleLinear(tensileLimit:min(x,y),range:min(r,s))
            default: cohesion = .none
            }
            parameters=try ContactResolvedParameters(normal:normal,friction:friction,resistance:resistance,resistanceRadius:resistanceRadius,cohesion:cohesion)
            provenance = .symmetricSeriesAndMinima
        }
        try lossPolicy.validate(normal:parameters.normal)
        try work.checkCancellation()
        return ContactLawPair(firstMaterial:a.reference,secondMaterial:b.reference,parameters:parameters,lossPolicy:lossPolicy,provenance:provenance)
    }
    private func series(_ x: Double,_ y: Double) throws(ContactLawError) -> Double {
        let sum=try contactFinite(1/x+1/y)
        guard sum > 0 else { throw .arithmeticFailure }
        let result=try contactFinite(1/sum)
        guard result > 0 else { throw .arithmeticFailure }; return result
    }
}
