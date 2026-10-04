import SwiftMechanics

enum GranularRuntimeParticleFixtures {
    static func ref(_ key: String,_ kind: EntityKind) throws -> ModelReference { ModelReference(id:try EntityID(kind:kind,key:key),revision:1) }
    static func proxy(_ key: String, shape: CollisionShape, position: Vector3, rotation: UnitQuaternion = .identity, mask: UInt64 = 1) throws -> CollisionProxy {
        let representation=try GeometryRepresentation(kind:.collisionGeometry,assetKey:"analytic",provenance:SourceProvenance(source:"fixture",revision:1),quality:.exact)
        return try CollisionProxy(colliderID:ref(key+"-collider",.collider).id,bodyID:ref(key,.body).id,frameID:ref("world",.frame).id,
            geometryRevision:1,frameRevision:1,shape:shape,margin:0,representations:BodyRepresentations(collisionGeometry:representation),expectedSourceRevision:1,
            resolution:.analytic,pose:RigidTransform(rotation:rotation,translation:position),filter:ColliderFilter(enabled:true,layerBits:1,maskBits:mask,isTrigger:false))
    }
    static func material(_ key: String, damping: Double = 0, friction: Bool = false, cohesion: Bool = false) throws -> ContactMaterial {
        let f: ContactFrictionLaw = friction ? .elasticCoulomb(try ContactFrictionParameters(staticFirst:0.8,staticSecond:0.8,dynamicFirst:0.4,dynamicSecond:0.4,tangentialStiffness:200,transitionSpeed:0.1)) : .none
        return try ContactMaterial(reference:ref(key,.material),youngModulus:1e6,poissonsRatio:0.25,linearStiffness:2000,normalDamping:damping,
            huntCrossleyAlpha:0,friction:f,resistance:ContactResistanceParameters(rollingCoefficient:0,spinningCoefficient:0,angularRegularization:0.1),
            cohesion:cohesion ? .reversibleLinear(tensileLimit:10,range:0.1) : .none)
    }
    static func pair(_ first: String,_ second: String,damping: Double = 0,friction: Bool = false,cohesion: Bool = false,
        loss: ContactLossPolicy = .compliantDampingOnly) throws -> ContactLawPair {
        var work=try contactWork()
        let service: any ContactMaterialPairing=SeriesContactPairing()
        return try service.combine(first:material(first,damping:damping,friction:friction,cohesion:cohesion),second:material(second,damping:damping,friction:friction,cohesion:cohesion),
            selection:.linear(maximumPenetration:0.4,maximumNormalSpeed:100),lossPolicy:loss,resistanceRadius:0.5,override:nil,work:&work)
    }
    static func policy(particles: Int = 32,boundaries: Int = 8,contacts: Int = 1024,neighbors: Int = 1024,cancel: @escaping @Sendable () -> Bool = { false }) throws -> GranularPolicy {
        try GranularPolicy(maximumParticles:particles,maximumBoundaries:boundaries,maximumContacts:contacts,maximumNeighbors:neighbors,
            momentumTolerance:1e-10,angularMomentumTolerance:1e-10,energyTolerance:1e-9,referenceMomentum:1,referenceAngularMomentum:1,referenceEnergy:1,relativeTolerance:1e-10,
            minimumTransportDot:-0.999999,collision:CollisionQueryPolicy(absoluteLengthTolerance:1e-10,relativeLengthTolerance:1e-10,referenceLength:1,maximumApproximationError:0),
            contact:ContactAcceptancePolicy(absoluteEnergyTolerance:1e-10,absolutePowerTolerance:1e-10,relativeTolerance:1e-10,referenceEnergy:1,referencePower:1,coneTolerance:1e-10),isCancelled:cancel)
    }
    static func numerical(operations: Int = 10_000_000,storage: Int = 100_000,iterations: Int = 10000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations))
    }
    static func contactWork(operations: Int = 10_000_000) throws -> ContactWork { ContactWork(budget:try ContactBudget(operations:operations,scalarStorage:10000,records:100)) }
    static func collisionWork(operations: Int = 10_000_000) throws -> CollisionWork { CollisionWork(budget:try CollisionBudget(scalarStorage:10000,operations:operations,iterations:10000,records:100)) }
    static func supplier(_ calls: Int = 10000) throws -> GranularSupplierWork { try GranularSupplierWork(maximumCalls:calls) }
    static func prepare(motions: [GranularMotion],plane: Bool = false,planeVelocity: Vector3 = .zero,damping: Double = 0,friction: Bool = false,cohesion: Bool = false,
        loss: ContactLossPolicy = .compliantDampingOnly,rotation: UnitQuaternion = .identity,random: RuntimeRandomState = RuntimeRandomState(seed:123),particleMass: Double = 1,policy: GranularPolicy? = nil) throws -> GranularState {
        var particles=[GranularParticle](), boundaries=[GranularBoundary](), laws=[ContactLawPair]()
        for i in motions.indices { particles.append(try GranularParticle(proxy:proxy("p"+String(i),shape:.sphere(radius:0.5),position:motions[i].position),body:ref("p"+String(i),.body),material:ref("m"+String(i),.material),mass:particleMass)) }
        if plane { boundaries.append(try GranularBoundary(proxy:proxy("wall",shape:.halfSpace,position:.zero,rotation:rotation),body:ref("wall",.body),material:ref("wall-material",.material),velocityAtOrigin:planeVelocity,normalVelocityTolerance:1e-12,angularAlignmentTolerance:1e-12)) }
        for i in motions.indices { for j in (i+1)..<motions.count { laws.append(try pair("m"+String(i),"m"+String(j),damping:damping,friction:friction,cohesion:cohesion,loss:loss)) } }
        if plane { for i in motions.indices { laws.append(try pair("m"+String(i),"wall-material",damping:damping,friction:friction,cohesion:cohesion,loss:loss)) } }
        var n=try numerical(),c=try contactWork(),s=try supplier()
        let service: any GranularPreparing=ReferenceGranularPreparation()
        return try service.prepare(revision:1,frame:ref("world",.frame),particles:particles,boundaries:boundaries,laws:laws,motions:motions,random:random,timeSeconds:0,
            policy:policy ?? self.policy(),numericalWork:&n,contactWork:&c,supplierWork:&s)
    }
    static func step(_ state: GranularState,h: Double = 0.001,gravity: Vector3 = .zero,policy: GranularPolicy? = nil,
        workspace: inout GranularWorkspace,service: any GranularEvolving = ReferenceGranularEvolution()) throws -> GranularStepResult {
        var n=try numerical(),c=try contactWork(),q=try collisionWork(),s=try supplier()
        return try service.step(accepted:state,timeStepSeconds:h,gravity:gravity,policy:policy ?? self.policy(),workspace:&workspace,numericalWork:&n,collisionWork:&q,contactWork:&c,supplierWork:&s)
    }
    static func close(_ a: Double,_ b: Double,_ tolerance: Double = 1e-9) -> Bool { abs(a-b) <= tolerance+1e-10*abs(b) }
    static func same(_ a: GranularState,_ b: GranularState) -> Bool {
        guard a.model === b.model, a.motions == b.motions, a.random == b.random, a.steps == b.steps, a.timeSeconds == b.timeSeconds, a.contacts.count == b.contacts.count else { return false }
        for i in a.contacts.indices { if a.contacts[i].history != b.contacts[i].history || a.contacts[i].basis != b.contacts[i].basis { return false } }
        return true
    }
}
