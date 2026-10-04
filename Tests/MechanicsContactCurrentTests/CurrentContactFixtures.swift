import SwiftMechanics

enum CurrentContactFixtures {
    static func reference(_ key:String,kind:EntityKind,revision:UInt64=1) throws -> ModelReference {
        ModelReference(id:try EntityID(kind:kind,key:key),revision:revision)
    }
    static func identity(geometryRevision:UInt64=1,layoutRevision:UInt64=1) throws -> ContactIdentity {
        try ContactIdentity(key:"contact",firstBody:reference("a",kind:.body),secondBody:reference("b",kind:.body),
            frame:reference("world",kind:.frame),firstGeometryRevision:geometryRevision,secondGeometryRevision:1,tangentLayoutRevision:layoutRevision)
    }
    static func friction(staticFirst:Double=0.8,staticSecond:Double=0.8,dynamicFirst:Double=0.4,dynamicSecond:Double=0.4) throws -> ContactFrictionLaw {
        .elasticCoulomb(try ContactFrictionParameters(staticFirst:staticFirst,staticSecond:staticSecond,dynamicFirst:dynamicFirst,dynamicSecond:dynamicSecond,
            tangentialStiffness:2000,transitionSpeed:0.1))
    }
    static func material(_ key:String,revision:UInt64=1,stiffness:Double=2000,damping:Double=0,alpha:Double=0,
                         modulus:Double=1e6,poisson:Double=0.25,friction:ContactFrictionLaw = .none,
                         rolling:Double=0,spinning:Double=0,cohesion:ContactCohesionLaw = .none) throws -> ContactMaterial {
        try ContactMaterial(reference:reference(key,kind:.material,revision:revision),youngModulus:modulus,poissonsRatio:poisson,
            linearStiffness:stiffness,normalDamping:damping,huntCrossleyAlpha:alpha,friction:friction,
            resistance:ContactResistanceParameters(rollingCoefficient:rolling,spinningCoefficient:spinning,angularRegularization:0.1),cohesion:cohesion)
    }
    static func work(operations:Int=2_000_000,storage:Int=10000,records:Int=1) throws -> ContactWork {
        ContactWork(budget:try ContactBudget(operations:operations,scalarStorage:storage,records:records))
    }
    static func pair(selection:ContactNormalSelection = .linear(maximumPenetration:0.2,maximumNormalSpeed:100),
                     damping:Double=0,alpha:Double=0,friction:ContactFrictionLaw = .none,rolling:Double=0,spinning:Double=0,
                     cohesion:ContactCohesionLaw = .none,loss:ContactLossPolicy = .compliantDampingOnly) throws -> ContactLawPair {
        var work=try work()
        let pairing:any ContactMaterialPairing=SeriesContactPairing()
        return try pairing.combine(first:material("mA",damping:damping,alpha:alpha,friction:friction,rolling:rolling,spinning:spinning,cohesion:cohesion),
            second:material("mB",damping:damping,alpha:alpha,friction:friction,rolling:rolling,spinning:spinning,cohesion:cohesion),
            selection:selection,lossPolicy:loss,resistanceRadius:0.5,override:nil,work:&work)
    }
    static func policy() throws -> ContactAcceptancePolicy {
        try ContactAcceptancePolicy(absoluteEnergyTolerance:1e-10,absolutePowerTolerance:1e-10,relativeTolerance:1e-11,
            referenceEnergy:1,referencePower:1,coneTolerance:1e-11)
    }
    static func input(identity:ContactIdentity?=nil,separation:Double = -0.01,velocity:Vector3 = .zero,angular:Vector3 = .zero,
                      time:Double=0,step:Double=0.001,rotation:UnitQuaternion = .identity) throws -> ContactInput {
        let id=try identity ?? self.identity()
        return try ContactInput(identity:id,basis:ContactBasis(frame:id.frame,contactToQuery:rotation),separation:separation,
            relativeVelocity:velocity,relativeAngularVelocity:angular,startTimeSeconds:time,timeStepSeconds:step)
    }
    static func history(_ pair:ContactLawPair,identity:ContactIdentity?=nil,time:Double=0) throws -> ContactHistory {
        var work=try work(); let evaluator:any ContactLawEvaluating=CompliantContactEvaluator()
        return try evaluator.initialHistory(identity:identity ?? self.identity(),pair:pair,timeSeconds:time,work:&work)
    }
    static func evaluate(_ input:ContactInput,pair:ContactLawPair,accepted:ContactHistory?=nil) throws -> ContactResponse {
        var work=try work(); let evaluator:any ContactLawEvaluating=CompliantContactEvaluator()
        return try evaluator.evaluate(input:input,pair:pair,accepted:accepted ?? history(pair,identity:input.identity,time:input.startTimeSeconds),policy:policy(),work:&work)
    }
    static func current(identity:ContactIdentity?=nil,separation:Double = -0.01,velocity:Vector3 = .zero,angular:Vector3 = .zero,
                        time:Double=0,rotation:UnitQuaternion = .identity) throws -> ContactCurrentInput {
        let id=try identity ?? self.identity()
        return try ContactCurrentInput(identity:id,basis:ContactBasis(frame:id.frame,contactToQuery:rotation),separation:separation,
            relativeVelocity:velocity,relativeAngularVelocity:angular,timeSeconds:time)
    }
    static func sample(_ input:ContactCurrentInput,pair:ContactLawPair,accepted:ContactHistory?=nil) throws -> ContactCurrentResponse {
        var work=try work(); let sampler:any ContactCurrentEvaluating=CompliantContactCurrentEvaluator()
        return try sampler.sample(input:input,pair:pair,accepted:accepted ?? history(pair,identity:input.identity,time:input.timeSeconds),policy:policy(),work:&work)
    }
    static func close(_ x:Double,_ y:Double) -> Bool { abs(x-y) <= 1e-9+1e-10*abs(y) }
    static func close(_ x:Vector3,_ y:Vector3) throws -> Bool { try x.subtracting(y).magnitude() <= 1e-9+1e-10*y.magnitude() }
}
