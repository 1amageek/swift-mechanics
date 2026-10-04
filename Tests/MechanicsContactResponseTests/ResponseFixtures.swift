import SwiftMechanics
internal enum ResponseFixtures {
    static func id(_ kind: EntityKind,_ key: String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func work(storage: Int=1000000, operations: Int=10000000, iterations: Int=10000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations))
    }
    static func lawWork(operations: Int=1000000) throws -> ContactWork { ContactWork(budget:try ContactBudget(operations:operations,scalarStorage:10000,records:10)) }
    static func pair(damping: Double=0, friction: ContactFrictionLaw = .none) throws -> ContactLawPair {
        var work=try lawWork()
        func material(_ key: String) throws -> ContactMaterial {
            try ContactMaterial(reference:ModelReference(id:id(.material,key),revision:1),youngModulus:1e6,poissonsRatio:0.2,linearStiffness:2000,normalDamping:damping,
                huntCrossleyAlpha:0,friction:friction,resistance:ContactResistanceParameters(rollingCoefficient:0,spinningCoefficient:0,angularRegularization:0.1),cohesion:.none)
        }
        let supplier:any ContactMaterialPairing=SeriesContactPairing()
        return try supplier.combine(first:material("material-a"),second:material("material-b"),selection:.linear(maximumPenetration:1,maximumNormalSpeed:100),
            lossPolicy:.compliantDampingOnly,resistanceRadius:0.5,override:nil,work:&work)
    }
    static func properties(_ mass: Double) throws -> MassProperties3D {
        try MassProperties3D(mass:mass,centerOfMass:.zero,inertiaAtCenter:Matrix3(2,0,0,0,3,0,0,0,4),policy:InertiaValidationPolicy(symmetry:NumericalTolerance(absolute:0,relative:0),physicalityRelative:0))
    }
    static func body(_ key: String,_ mass: Double) throws -> KinematicBody {
        KinematicBody(body:try BodyRecord3D(id:id(.body,key),frame:id(.frame,key+"-frame"),mode:.dynamic,bodyToWorld:.identity,representations:BodyRepresentations(),
            inertia:InertialRepresentation3D(properties:properties(mass),provenance:SourceProvenance(source:"mass",revision:1),quality:.exact)))
    }
    static func joint(_ key: String,_ a: String,_ b: String, hinge: Bool=false, prescribed: Bool=false) throws -> JointRecord {
        try JointRecord(id:id(.joint,key),parentBody:id(.body,a),childBody:id(.body,b),
            parentAnchor:JointAnchor(frame:id(.frame,key+"-parent"),placement:prescribed ? .prescribed : .fixed(.identity)),
            childAnchor:JointAnchor(frame:id(.frame,key+"-child"),placement:.fixed(.identity)),
            manifold:JointManifold(hinge ? .revolute(axis:.unitY) : .prismatic(axis:.unitZ)))
    }
    static func system(stack: Bool=false, hinge: Bool=false, drift: Double=0, gravity: Bool=false) throws -> RigidDynamicsSystem {
        let bodies=try stack ? [body("ground",1),body("lower",2),body("upper",3)] : [body("ground",1),body("lower",2)]
        let first=try joint("first","ground","lower",hinge:hinge,prescribed:drift != 0)
        let joints=try stack ? [first,joint("second","lower","upper")] : [first]
        let n=stack ? 2 : 1
        let tree=try KinematicTree(bodies:bodies,joints:joints,root:id(.body,"ground"),rootBase:.fixed,worldFrame:id(.frame,"world"),revision:1,
            capacity:KinematicCapacity(maximumBodies:3,maximumVelocities:2,maximumJacobianScalars:36))
        let anchors=try drift == 0 ? [] : [PrescribedAnchorState(frame:first.parentAnchor.frame,time:0,motion:FrameMotion(pose:.identity,
            velocity:SpatialMotion(angular:.zero,linear:Vector3(0,0,drift)),acceleration:SpatialMotion(angular:.zero,linear:.zero)))]
        let state=try KinematicState(revision:1,time:0,q:hinge ? [0] : (stack ? [0.9,0.9] : [0.9]),v:[Double](repeating:0,count:n),acceleration:[Double](repeating:99,count:n),prescribedAnchors:anchors)
        let snapshot=try TreeKinematicsEvaluator().evaluate(tree,state:state,policy:JointEvaluationPolicy(quaternionTolerance:NumericalTolerance(absolute:1e-12,relative:1e-12),chartRankRelative:1e-10,characteristicLengthMeters:1))
        var inertias:[RigidBodyInertia]=[]
        for (i,key) in ["ground","lower","upper"].prefix(bodies.count).enumerated() { inertias.append(try RigidBodyInertia(body:id(.body,key),frame:id(.frame,key+"-frame"),properties:properties(i == 0 ? 1 : (i == 1 ? 2 : 3)))) }
        let input=try RigidDynamicsInput(snapshot:snapshot,velocity:[Double](repeating:0,count:n),inertias:inertias,
            gravity:gravity ? AffineGravity(frame:id(.frame,"world"),accelerationAtOrigin:Vector3(0,0,-10)) : nil)
        var work=try work(), load=LoadWork(budget:try LoadBudget(maximumWork:100,maximumScalars:0))
        let supplier:any RigidEquationComputing=RigidEquationKernel()
        return try supplier.assemble(input,admission:DynamicsAdmission(capacity:DynamicsCapacity(maximumBodies:3,maximumVelocities:2,maximumBodyWrenches:0,maximumGeneralizedContributions:0),
            angularVelocityTolerance:NumericalTolerance(absolute:1e-10,relative:1e-10),linearVelocityTolerance:NumericalTolerance(absolute:1e-10,relative:1e-10)),loadWork:&load,work:&work)
    }
    static func proxy(_ key: String,body: String,pose: RigidTransform, geometryRevision: UInt64=1, mask: UInt64=1) throws -> CollisionProxy {
        try CollisionProxy(colliderID:id(.collider,key),bodyID:id(.body,body),frameID:id(.frame,"world"),geometryRevision:geometryRevision,frameRevision:1,
            shape:.sphere(radius:0.5),margin:0,representations:BodyRepresentations(collisionGeometry:GeometryRepresentation(kind:.collisionGeometry,assetKey:"sphere",
                provenance:SourceProvenance(source:"analytic physical",revision:1),quality:.exact)),expectedSourceRevision:1,resolution:.analytic,pose:pose,
            filter:ColliderFilter(enabled:true,layerBits:1,maskBits:mask,isTrigger:false))
    }
    static func input(stack: Bool=false, hinge: Bool=false, duplicate: Bool=false, drift: Double=0, gravity: Bool=false,
                      damping: Double=0, friction: ContactFrictionLaw = .none, separated: Bool=false) throws -> ContactResponseInput {
        let system=try system(stack:stack,hinge:hinge,drift:drift,gravity:gravity), snapshot=system.input.snapshot
        let localA=RigidTransform(rotation:.identity,translation:try Vector3(hinge ? 1 : 0,0,hinge ? -0.9 : 0))
        let localB=RigidTransform(rotation:.identity,translation:try Vector3(hinge ? 1 : 0,0,separated ? 0.2 : 0))
        let poseA=try snapshot.body(id(.body,"ground")).motion.pose.composed(with:localA)
        let poseB=try snapshot.body(id(.body,"lower")).motion.pose.composed(with:localB)
        var proxies=try [proxy("ground-collider",body:"ground",pose:poseA),proxy("lower-collider",body:"lower",pose:poseB)]
        if stack { proxies.append(try proxy("upper-collider",body:"upper",pose:snapshot.body(id(.body,"upper")).motion.pose)) }
        let collision=try CollisionSnapshot(proxies:proxies,revision:1), pair=try pair(damping:damping,friction:friction)
        var contacts:[WitnessContact]=[], geometryWork=CollisionWork(budget:try CollisionBudget(scalarStorage:1000,operations:100000,iterations:0,records:10)), historyWork=try lawWork()
        let geometry:any CollisionGeometryQuerying=AnalyticCollisionQueries(), law:any ContactLawEvaluating=CompliantContactEvaluator()
        let count=stack ? 2 : (duplicate ? 2 : 1)
        for i in 0..<count {
            let a=stack ? i : 0,b=stack ? i+1 : 1
            let witness=try geometry.witness(first:proxies[a],second:proxies[b],policy:CollisionQueryPolicy(absoluteLengthTolerance:1e-10,relativeLengthTolerance:1e-10,referenceLength:1,maximumApproximationError:0),work:&geometryWork)
            let identity=try ContactIdentity(key:"contact-"+String(i),firstBody:ModelReference(id:proxies[a].geometry.bodyID,revision:1),secondBody:ModelReference(id:proxies[b].geometry.bodyID,revision:1),
                frame:ModelReference(id:id(.frame,"world"),revision:1),firstGeometryRevision:1,secondGeometryRevision:1,tangentLayoutRevision:1)
            let accepted=try law.initialHistory(identity:identity,pair:pair,timeSeconds:0,work:&historyWork)
            contacts.append(WitnessContact(coordinateID:UInt64(i+1),tangentLayoutRevision:1,witness:witness,firstProxyIndex:a,secondProxyIndex:b,
                firstColliderToBody:a == 0 ? localA : .identity,secondColliderToBody:b == 1 ? localB : .identity,
                basis:try ContactBasis(frame:identity.frame,contactToQuery:.identity),pair:pair,accepted:accepted))
        }
        return try ContactResponseInput(system:system,collision:collision,expectedCollisionRevision:1,expectedModelRevision:1,contacts:contacts,driveForce:[Double](repeating:0,count:system.velocityCount),timeStep:0.1)
    }
    static func policy(_ n: Int=1, contacts: Int=5, looseCone: Bool=false, iterations: Int=2000, cancelled: Bool=false) throws -> ContactResponsePolicy {
        try ContactResponsePolicy(maximumContacts:contacts,maximumColliders:5,maximumBodies:5,maximumVelocities:5,lengthTolerance:1e-9,normalTolerance:1e-9,
            forceScale:100,lengthScale:1,powerScale:100,originalTolerance:1e-7,
            dynamics:DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),linearTolerance:LinearTolerance(absoluteResidual:1e-9,relativeResidual:1e-10,pivotThreshold:1e-12),coordinateScales:[Double](repeating:1,count:n),energyScale:1,timeScale:1),
            law:ContactAcceptancePolicy(absoluteEnergyTolerance:1e-9,absolutePowerTolerance:1e-9,relativeTolerance:1e-10,referenceEnergy:1,referencePower:1,coneTolerance:1e-9),
            coneTolerance:ConeTolerance(absolutePrimal:looseCone ? 10 : 1e-10,absoluteDual:looseCone ? 10 : 1e-10,absoluteComplementarity:looseCone ? 10 : 1e-10,absoluteOptimality:looseCone ? 10 : 1e-10,relative:0,primalScale:1,dualScale:1),
            precision:.float64,backend:.referenceCPU,maximumConeIterations:iterations,conePivotThreshold:1e-12,isCancelled:{cancelled})
    }
    static func solve(_ input: ContactResponseInput, policy: ContactResponsePolicy?=nil) throws -> ContactResponseSolution {
        var outer=try work(), dynamics=try work(), cone=try work(), law=try lawWork()
        let service:any CoupledContactResponding=ImplicitLinearNormalResponse()
        return try service.solve(input,policy:policy ?? self.policy(input.system.velocityCount),responseWork:&outer,dynamicsWork:&dynamics,coneWork:&cone,lawWork:&law)
    }
    static func close(_ a: Double,_ b: Double) -> Bool { abs(a-b) <= 1e-6*max(1,abs(b)) }
}
