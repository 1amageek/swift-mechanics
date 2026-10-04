import SwiftMechanics

enum ContactDerivativeFixtures {
    static func reference(_ key: String, _ kind: EntityKind) throws -> ModelReference {
        ModelReference(id:try EntityID(kind:kind,key:key),revision:1)
    }
    static func identity() throws -> ContactIdentity {
        try ContactIdentity(key:"derivative",firstBody:reference("a",.body),secondBody:reference("b",.body),
            frame:reference("world",.frame),firstGeometryRevision:1,secondGeometryRevision:2,tangentLayoutRevision:3)
    }
    static func pair(_ normal: ContactNormalLaw = .linear(stiffness:1000,damping:20,maximumPenetration:0.5,maximumNormalSpeed:100),
                     loss: ContactLossPolicy = .compliantDampingOnly, friction: ContactFrictionLaw = .none) throws -> ContactLawPair {
        let a=try reference("mA",.material), b=try reference("mB",.material)
        let resistance=try ContactResistanceParameters(rollingCoefficient:0,spinningCoefficient:0,angularRegularization:0.1)
        let ma=try ContactMaterial(reference:a,youngModulus:1e6,poissonsRatio:0.25,linearStiffness:2000,normalDamping:0,
            huntCrossleyAlpha:0,friction:friction,resistance:resistance,cohesion:.none)
        let mb=try ContactMaterial(reference:b,youngModulus:1e6,poissonsRatio:0.25,linearStiffness:2000,normalDamping:0,
            huntCrossleyAlpha:0,friction:friction,resistance:resistance,cohesion:.none)
        let parameters=try ContactResolvedParameters(normal:normal,friction:friction,resistance:resistance,resistanceRadius:0.5,cohesion:.none)
        let override=try ContactPairOverride(first:a,second:b,revision:7,parameters:parameters)
        var work=try primalWork()
        let service: any ContactMaterialPairing=SeriesContactPairing()
        return try service.combine(first:ma,second:mb,selection:.linear(maximumPenetration:0.5,maximumNormalSpeed:100),
            lossPolicy:loss,resistanceRadius:0.5,override:override,work:&work)
    }
    static func acceptance() throws -> ContactAcceptancePolicy {
        try ContactAcceptancePolicy(absoluteEnergyTolerance:1e-10,absolutePowerTolerance:1e-10,relativeTolerance:1e-11,
            referenceEnergy:1,referencePower:1,coneTolerance:1e-11)
    }
    static func policy(sr: Double=0.001, vr: Double=0.01, bytes: Int=1000,
                       cancelled: @escaping @Sendable () -> Bool = { false }) throws -> ContactDerivativePolicy {
        try ContactDerivativePolicy(separationRadius:sr,normalSpeedRadius:vr,maximumIdentifierBytes:bytes,
            absolutePrimalTolerance:1e-11,relativePrimalTolerance:1e-11,acceptance:acceptance(),isCancelled:cancelled)
    }
    static func work(_ operations: Int=100_000, storage: Int=10_000) throws -> ContactDerivativeWork {
        ContactDerivativeWork(budget:try ContactBudget(operations:operations,scalarStorage:storage,records:1))
    }
    static func primalWork() throws -> ContactWork {
        ContactWork(budget:try ContactBudget(operations:100_000,scalarStorage:10_000,records:1))
    }
    static func input(s: Double = -0.02, vn: Double = -0.1, rotation: UnitQuaternion = .identity) throws -> ContactInput {
        let id=try identity(), basis=try ContactBasis(frame:id.frame,contactToQuery:rotation)
        return try ContactInput(identity:id,basis:basis,separation:s,relativeVelocity:basis.normal.scaled(by:vn),
            relativeAngularVelocity:.zero,startTimeSeconds:0,timeStepSeconds:0.001)
    }
    static func history(_ pair: ContactLawPair, input: ContactInput) throws -> ContactHistory {
        var work=try primalWork(); let service: any ContactLawEvaluating=CompliantContactEvaluator()
        return try service.initialHistory(identity:input.identity,pair:pair,timeSeconds:input.startTimeSeconds,work:&work)
    }
    static func close(_ a: Double,_ b: Double) -> Bool { abs(a-b) <= 1e-9+abs(b)*1e-10 }
}
