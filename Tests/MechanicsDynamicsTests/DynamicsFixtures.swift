import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints
import MechanicsLoads
import MechanicsDynamics
struct DynamicsFixtures {
    static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func properties(mass: Double, com: Vector3 = .zero, inertia: Matrix3 = .identity) throws -> MassProperties3D {
        try MassProperties3D(mass:mass,centerOfMass:com,inertiaAtCenter:inertia,
            policy:InertiaValidationPolicy(symmetry:NumericalTolerance(absolute:0,relative:0),physicalityRelative:0))
    }
    static func body(_ key: String, properties: MassProperties3D) throws -> KinematicBody {
        KinematicBody(body:try BodyRecord3D(id:id(.body,key),frame:id(.frame,key+"-frame"),mode:.dynamic,bodyToWorld:.identity,
            representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:properties,
                provenance:SourceProvenance(source:"inertia",revision:1),quality:.exact)))
    }
    static func inertia(_ key: String, _ properties: MassProperties3D) throws -> RigidBodyInertia {
        try RigidBodyInertia(body:id(.body,key),frame:id(.frame,key+"-frame"),properties:properties)
    }
    static func hinge(_ key: String, parent: String, child: String, parentPlacement: AnchorPlacement = .fixed(.identity)) throws -> JointRecord {
        try JointRecord(id:id(.joint,key),parentBody:id(.body,parent),childBody:id(.body,child),
            parentAnchor:JointAnchor(frame:id(.frame,key+"-parent"),placement:parentPlacement),
            childAnchor:JointAnchor(frame:id(.frame,key+"-child"),placement:.fixed(.identity)),manifold:JointManifold(.revolute(axis:.unitZ)))
    }
    static func snapshot(bodies: [KinematicBody], joints: [JointRecord], root: String, base: BaseLayout = .fixed,
                         q: [Double], v: [Double], acceleration: [Double], anchors: [PrescribedAnchorState] = []) throws -> KinematicSnapshot {
        let tree = try KinematicTree(bodies:bodies,joints:joints,root:id(.body,root),rootBase:base,worldFrame:id(.frame,"world"),revision:7,
            capacity:KinematicCapacity(maximumBodies:10,maximumVelocities:20,maximumJacobianScalars:1200))
        return try TreeKinematicsEvaluator().evaluate(tree,state:KinematicState(revision:7,time:0,q:q,v:v,acceleration:acceleration,prescribedAnchors:anchors),
            policy:JointEvaluationPolicy(quaternionTolerance:NumericalTolerance(absolute:1e-12,relative:1e-12),chartRankRelative:1e-10,characteristicLengthMeters:1))
    }
    static func admission(cancelled: Bool = false, bodies: Int = 10) throws -> DynamicsAdmission {
        DynamicsAdmission(capacity:try DynamicsCapacity(maximumBodies:bodies,maximumVelocities:20,maximumBodyWrenches:20,maximumGeneralizedContributions:20),
            angularVelocityTolerance:try NumericalTolerance(absolute:1e-11,relative:1e-11),linearVelocityTolerance:try NumericalTolerance(absolute:1e-11,relative:1e-11),
            isCancelled:{ cancelled })
    }
    static func loadWork() throws -> LoadWork { LoadWork(budget:try LoadBudget(maximumWork:1000,maximumScalars:0)) }
    static func work(storage: Int = 100000, operations: Int = 1000000, iterations: Int = 100) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations))
    }
    static func policy(_ count: Int, scales: [Double]? = nil, energy: Double = 1, time: Double = 1,
                       pivot: Double = 1e-12, algorithm: LinearAlgorithm = .cholesky) throws -> DynamicsSolvePolicy {
        try DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:algorithm),
            linearTolerance:LinearTolerance(absoluteResidual:1e-9,relativeResidual:1e-10,pivotThreshold:pivot),
            coordinateScales:scales ?? [Double](repeating:1,count:count),energyScale:energy,timeScale:time)
    }
    static func pendulum(theta: Double = 0.4, speed: Double = 0.7, acceleration: Double = 0,
                         prescribed: Bool = false, loads: [BodyWrenchContribution] = []) throws -> RigidDynamicsInput {
        let root = try properties(mass:1), child = try properties(mass:2,com:Vector3(1,0,0),inertia:Matrix3(2,0,0,0,3,0,0,0,4))
        let joint = try hinge("hinge",parent:"root",child:"pendulum",parentPlacement:prescribed ? .prescribed : .fixed(.identity))
        let anchors = prescribed ? [try PrescribedAnchorState(frame:joint.parentAnchor.frame,time:0,
            motion:FrameMotion(pose:.identity,velocity:SpatialMotion(angular:.zero,linear:Vector3(4,0,0)),
                acceleration:SpatialMotion(angular:.zero,linear:Vector3(3,0,0))))] : []
        let snapshot = try snapshot(bodies:[body("root",properties:root),body("pendulum",properties:child)],joints:[joint],root:"root",
            q:[theta],v:[speed],acceleration:[acceleration],anchors:anchors)
        return try RigidDynamicsInput(snapshot:snapshot,velocity:[speed],inertias:[inertia("root",root),inertia("pendulum",child)],
            gravity:AffineGravity(frame:id(.frame,"world"),accelerationAtOrigin:Vector3(0,-10,0)),bodyWrenches:loads)
    }
    static func twoLink(acceleration: [Double] = [0,0]) throws -> RigidDynamicsInput {
        let root = try properties(mass:1)
        let first = try properties(mass:2,com:Vector3(0.7,0,0),inertia:Matrix3(0.6,0,0,0,0.7,0,0,0,1))
        let second = try properties(mass:3,com:Vector3(0.8,0,0),inertia:Matrix3(0.6,0,0,0,0.6,0,0,0,0.9))
        let firstJoint = try hinge("first-joint",parent:"root",child:"first")
        let secondJoint = try hinge("second-joint",parent:"first",child:"second",parentPlacement:.fixed(RigidTransform(rotation:.identity,translation:Vector3(2,0,0))))
        let snapshot = try snapshot(bodies:[body("root",properties:root),body("first",properties:first),body("second",properties:second)],joints:[firstJoint,secondJoint],root:"root",q:[0.3,-0.6],v:[0.8,-0.4],acceleration:acceleration)
        return try RigidDynamicsInput(snapshot:snapshot,velocity:[0.8,-0.4],inertias:[inertia("root",root),inertia("first",first),inertia("second",second)],
            gravity:AffineGravity(frame:id(.frame,"world"),accelerationAtOrigin:Vector3(0,-10,0)))
    }
}
