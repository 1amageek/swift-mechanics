import SwiftMechanics
struct DerivativeFixtures {
    static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func properties(_ mass: Double, _ com: Vector3 = .zero, _ inertia: Matrix3 = .identity) throws -> MassProperties3D {
        try MassProperties3D(mass:mass,centerOfMass:com,inertiaAtCenter:inertia,
            policy:InertiaValidationPolicy(symmetry:NumericalTolerance(absolute:0,relative:0),physicalityRelative:0))
    }
    static func body(_ key: String, _ p: MassProperties3D) throws -> KinematicBody {
        KinematicBody(body:try BodyRecord3D(id:id(.body,key),frame:id(.frame,key+"-frame"),mode:.dynamic,bodyToWorld:.identity,
            representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:p,provenance:SourceProvenance(source:"derivative-physical",revision:1),quality:.exact)))
    }
    static func inertia(_ key: String, _ p: MassProperties3D) throws -> RigidBodyInertia { try RigidBodyInertia(body:id(.body,key),frame:id(.frame,key+"-frame"),properties:p) }
    static func hinge(_ key: String, _ parent: String, _ child: String, _ placement: AnchorPlacement = .fixed(.identity),
                      manifold: JointManifold? = nil) throws -> JointRecord {
        try JointRecord(id:id(.joint,key),parentBody:id(.body,parent),childBody:id(.body,child),
            parentAnchor:JointAnchor(frame:id(.frame,key+"-parent"),placement:placement),childAnchor:JointAnchor(frame:id(.frame,key+"-child"),placement:.fixed(.identity)),
            manifold:manifold ?? JointManifold(.revolute(axis:.unitZ)))
    }
    static func input(_ bodies: [KinematicBody], _ joints: [JointRecord], _ inertias: [RigidBodyInertia],
                      q: [Double], v: [Double], acceleration: [Double], base: BaseLayout = .fixed,
                      prescribed: [PrescribedAnchorState] = [], gravity: AffineGravity? = nil,
                      wrenches: [BodyWrenchContribution] = [], drive: [Double]? = nil) throws -> MechanicalDerivativeInput {
        let tree=try KinematicTree(bodies:bodies,joints:joints,root:bodies[0].id,rootBase:base,worldFrame:id(.frame,"world"),revision:7,
            capacity:KinematicCapacity(maximumBodies:20,maximumVelocities:30,maximumJacobianScalars:3600))
        let state=try KinematicState(revision:7,time:0,q:q,v:v,acceleration:acceleration,prescribedAnchors:prescribed)
        return MechanicalDerivativeInput(tree:tree,state:state,inertias:inertias,gravity:gravity,bodyWrenches:wrenches,drive:drive ?? [Double](repeating:0,count:v.count))
    }
    static func pendulum(prescribed: Bool = false, wrenches: [BodyWrenchContribution] = [], gravityTime: Vector3 = .zero) throws -> MechanicalDerivativeInput {
        let root=try properties(1), child=try properties(2,Vector3(1,0,0),Matrix3(2,0,0,0,3,0,0,0,4))
        let joint=try hinge("hinge","root","pendulum",prescribed ? .prescribed : .fixed(.identity))
        let samples=prescribed ? [try PrescribedAnchorState(frame:joint.parentAnchor.frame,time:0,
            motion:FrameMotion(pose:.identity,velocity:SpatialMotion(angular:.zero,linear:Vector3(4,0,0)),
                acceleration:SpatialMotion(angular:.zero,linear:Vector3(3,0,0))))] : []
        return try input([body("root",root),body("pendulum",child)],[joint],[inertia("root",root),inertia("pendulum",child)],
            q:[0.4],v:[0.7],acceleration:[37],prescribed:samples,
            gravity:AffineGravity(frame:id(.frame,"world"),accelerationAtOrigin:Vector3(0,-10,0),uniformTimeDerivative:gravityTime),wrenches:wrenches,drive:[2])
    }
    static func twoLink() throws -> MechanicalDerivativeInput {
        let root=try properties(1), first=try properties(2,Vector3(0.7,0,0),Matrix3(0.6,0,0,0,0.7,0,0,0,1)),
            second=try properties(3,Vector3(0.8,0,0),Matrix3(0.6,0,0,0,0.6,0,0,0,0.9))
        let j1=try hinge("first-joint","root","first"), j2=try hinge("second-joint","first","second",.fixed(RigidTransform(rotation:.identity,translation:Vector3(2,0,0))))
        return try input([body("root",root),body("first",first),body("second",second)],[j1,j2],[inertia("root",root),inertia("first",first),inertia("second",second)],
            q:[0.3,-0.6],v:[0.8,-0.4],acceleration:[99,-17],gravity:AffineGravity(frame:id(.frame,"world"),accelerationAtOrigin:Vector3(0,-10,0)),drive:[1,-2])
    }
    static func freeBody() throws -> MechanicalDerivativeInput {
        let p=try properties(2,.zero,Matrix3(2,0,0,0,3,0,0,0,4)), rotation=try UnitQuaternion(axis:.unitZ,angle:0.7)
        return try input([body("free",p)],[],[inertia("free",p)],q:[0.2,0.4,-0.1,rotation.w,rotation.x,rotation.y,rotation.z],
            v:[0.3,-0.2,0.5,1,2,3],acceleration:[7,8,9,10,11,12],base:.spatialFloating)
    }
    static func zero(_ input: MechanicalDerivativeInput, q: [Double]? = nil, v: [Double]? = nil,
                     drive: [Double]? = nil, inertias: [BodyInertiaDirection]? = nil, time: Double = 0,
                     prescribed: [FrameMotionDirection]? = nil, gravity: Vector3 = .zero,
                     parameters: [Double]? = nil) -> MechanicalDirection {
        let n=input.tree.layout.velocityCount, zero=[Double](repeating:0,count:n)
        return MechanicalDirection(tree:TreeDirection(revision:input.tree.revision,configuration:q ?? zero,velocity:v ?? zero,acceleration:zero,screwPitch:zero,
            prescribed:prescribed ?? [FrameMotionDirection](repeating:FrameMotionDirection(),count:input.state.prescribedAnchors.count),time:time),
            inertias:inertias ?? input.inertias.map { BodyInertiaDirection(body:$0.body,frame:$0.frame) },gravity:gravity,
            bodyWrenches:input.bodyWrenches.map { BodyWrenchDirection(body:$0.body,frame:$0.frame) },
            generalizedForces:input.generalizedForces.map { _ in zero },drive:drive ?? zero,parameters:parameters ?? [Double](repeating:0,count:input.parameters.count))
    }
    static func policy(cancelled: Bool = false, columns: Int = 30) throws -> DerivativePolicy {
        try DerivativePolicy(maximumBodies:20,maximumVelocities:30,maximumJacobianColumns:columns,
            tolerance:NumericalTolerance(absolute:1e-8,relative:1e-10),residualTolerance:NumericalTolerance(absolute:1e-9,relative:1e-10),physicalNeighborhood:1e-3,
            inertiaValidation:InertiaValidationPolicy(symmetry:NumericalTolerance(absolute:0,relative:0),physicalityRelative:0),isCancelled:{ cancelled })
    }
    static func jointPolicy() throws -> JointEvaluationPolicy { try JointEvaluationPolicy(quaternionTolerance:NumericalTolerance(absolute:1e-12,relative:1e-12),chartRankRelative:1e-10,characteristicLengthMeters:1) }
    static func admission() throws -> DynamicsAdmission {
        DynamicsAdmission(capacity:try DynamicsCapacity(maximumBodies:20,maximumVelocities:30,maximumBodyWrenches:30,maximumGeneralizedContributions:30),
            angularVelocityTolerance:try NumericalTolerance(absolute:1e-10,relative:1e-10),linearVelocityTolerance:try NumericalTolerance(absolute:1e-10,relative:1e-10))
    }
    static func solvePolicy(_ n: Int, scaled: Bool = false) throws -> DynamicsSolvePolicy {
        try DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:LinearTolerance(absoluteResidual:1e-9,relativeResidual:1e-10,pivotThreshold:1e-12),
            coordinateScales:[Double](repeating:scaled ? 0.25 : 1,count:n),energyScale:scaled ? 7 : 1,timeScale:scaled ? 3 : 1)
    }
    static func work(storage: Int = 1000000, operations: Int = 10000000, iterations: Int = 100) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations))
    }
    static func loadWork() throws -> LoadWork { LoadWork(budget:try LoadBudget(maximumWork:10000,maximumScalars:0)) }
    static func tangent(_ input: MechanicalDerivativeInput, _ d: MechanicalDirection) throws -> MechanicalTangent {
        var s=MechanicalDerivativeWorkspace(), w=try work(), l=try loadWork(), calls=try DerivativeSupplierWork(maximumCalls:1000)
        let service:any MechanicalDifferentiating=ExactMechanicalDifferentiator()
        return try service.direction(input,direction:d,jointPolicy:jointPolicy(),admission:admission(),policy:policy(),workspace:&s,loadWork:&l,supplierWork:&calls,work:&w)
    }
    static func forward(_ input: MechanicalDerivativeInput, _ d: MechanicalDirection, scaled: Bool = false) throws -> AccelerationTangent {
        var s=MechanicalDerivativeWorkspace(), w=try work(), l=try loadWork(), calls=try DerivativeSupplierWork(maximumCalls:1000)
        let service:any MechanicalDifferentiating=ExactMechanicalDifferentiator()
        return try service.forwardDirection(input,direction:d,jointPolicy:jointPolicy(),admission:admission(),solvePolicy:solvePolicy(input.drive.count,scaled:scaled),policy:policy(),workspace:&s,loadWork:&l,supplierWork:&calls,work:&w)
    }
    static func shifted(_ input: MechanicalDerivativeInput, q: [Double]? = nil, v: [Double]? = nil) throws -> MechanicalDerivativeInput {
        MechanicalDerivativeInput(tree:input.tree,state:try KinematicState(revision:input.state.revision,time:input.state.time,q:q ?? input.state.q,v:v ?? input.state.v,
            acceleration:input.state.acceleration,prescribedAnchors:input.state.prescribedAnchors),inertias:input.inertias,gravity:input.gravity,
            bodyWrenches:input.bodyWrenches,generalizedForces:input.generalizedForces,drive:input.drive)
    }
    static func close(_ x: Double, _ y: Double, _ tolerance: Double = 1e-7) -> Bool { abs(x-y) <= tolerance*max(1,max(abs(x),abs(y))) }
}
