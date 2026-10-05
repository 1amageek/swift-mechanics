import SwiftMechanics
import Foundation

struct PlanarTreeFixtures {
    let tree: KinematicTree
    let state: KinematicState
    let direction: TreeDirection

    static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func pose(_ x: Double = 0, _ y: Double = 0, _ angle: Double = 0) throws -> RigidTransform {
        RigidTransform(rotation:try UnitQuaternion(axis:.unitZ,angle:angle),translation:try Vector3(x,y,0))
    }
    static func body(_ key: String, spatial: Bool = false, x: Double = 0, y: Double = 0, angle: Double = 0) throws -> KinematicBody {
        if spatial {
            return KinematicBody(body:try BodyRecord3D(id:id(.body,key),frame:id(.frame,key+"-frame"),mode:.static,
                bodyToWorld:.identity,representations:BodyRepresentations(),inertia:nil))
        }
        return try KinematicBody(body:BodyRecord2D(id:id(.body,key),frame:id(.frame,key+"-frame"),mode:.static,
            bodyToWorld:PlanarPose(x:x,y:y,angle:angle),representations:BodyRepresentations(),inertia:nil))
    }
    static func joint(_ key: String, _ parent: String, _ child: String, _ manifold: JointSpecification,
                      parentPose: RigidTransform = .identity, childPose: RigidTransform = .identity,
                      prescribed: Bool = false) throws -> JointRecord {
        try JointRecord(id:id(.joint,key),parentBody:id(.body,parent),childBody:id(.body,child),
            parentAnchor:JointAnchor(frame:id(.frame,key+"-parent"),placement:prescribed ? .prescribed : .fixed(parentPose)),
            childAnchor:JointAnchor(frame:id(.frame,key+"-child"),placement:prescribed ? .prescribed : .fixed(childPose)),
            manifold:JointManifold(manifold))
    }
    static func make(_ bodies: [KinematicBody], _ joints: [JointRecord], base: BaseLayout = .fixed,
                     q: [Double], v: [Double], a: [Double], dq: [Double], dv: [Double], da: [Double],
                     samples: [PrescribedAnchorState] = [], sampleDirections: [FrameMotionDirection] = []) throws -> Self {
        let tree=try KinematicTree(bodies:bodies,joints:joints,root:bodies[0].id,rootBase:base,
            worldFrame:id(.frame,"world"),revision:9,capacity:KinematicCapacity(maximumBodies:20,maximumVelocities:20,maximumJacobianScalars:2400))
        return Self(tree:tree,state:try KinematicState(revision:9,time:0.7,q:q,v:v,acceleration:a,prescribedAnchors:samples),
            direction:TreeDirection(revision:9,configuration:dq,velocity:dv,acceleration:da,screwPitch:[Double](repeating:0,count:v.count),
                prescribed:sampleDirections,time:samples.isEmpty ? 0 : 0.4))
    }
    static func hinge() throws -> Self {
        try make([body("root"),body("tip")],[joint("hinge","root","tip",.revolute(axis:.unitZ),childPose:pose(-2))],
            q:[0.4],v:[0.7],a:[13],dq:[0.3],dv:[-0.2],da:[0.9])
    }
    static func branched(_ floating: Bool) throws -> Self {
        let joints=try [joint("hinge","root","first",.revolute(axis:.unitZ),parentPose:pose(0.4,-0.3,0.2),childPose:pose(-1,0.2,-0.1)),
            joint("plane","root","branch",.planar(firstTranslationAxis:Vector3(1,1,0),secondTranslationAxis:.unitY),childPose:pose(0.3,-0.2,0.4)),
            joint("slide","first","slider",.prismatic(axis:Vector3(1,-0.4,0)),parentPose:pose(0.5,0.6,-0.3),childPose:pose(0.2,0.1,0.2))]
        let q=floating ? [0.2,-0.7,0.6,0.3,0.7,-0.2,0.5,-0.4] : [0.3,0.7,-0.2,0.5,-0.4]
        let v=floating ? [0.4,-0.5,0.8,0.6,-0.3,0.2,0.7,-0.4] : [0.6,-0.3,0.2,0.7,-0.4]
        return try make([body("root",x:0.2,y:-0.4,angle:0.35),body("first"),body("branch"),body("slider")],joints,base:floating ? .planarFloating : .fixed,
            q:q,v:v,a:v.map { 3+$0*7 },dq:v.map { $0*0.3 },dv:v.map { -$0*0.6 },da:v.map { $0*1.2 })
    }
    static func prescribed() throws -> Self {
        let j=try joint("moving","root","tip",.revolute(axis:.unitZ),prescribed:true)
        let samples=try [PrescribedAnchorState(frame:j.parentAnchor.frame,time:0.7,
            motion:FrameMotion(pose:pose(0.4,-0.6,0.3),velocity:SpatialMotion(angular:Vector3(0,0,0.5),linear:Vector3(0.2,-0.4,0)),
                acceleration:SpatialMotion(angular:Vector3(0,0,0.8),linear:Vector3(1.1,-0.3,0)))),
            PrescribedAnchorState(frame:j.childAnchor.frame,time:0.7,
                motion:FrameMotion(pose:pose(-1,0.2,-0.4),velocity:SpatialMotion(angular:Vector3(0,0,-0.3),linear:Vector3(-0.7,0.4,0)),
                    acceleration:SpatialMotion(angular:Vector3(0,0,0.6),linear:Vector3(0.9,-0.2,0))))]
        let directions=try [FrameMotionDirection(translation:Vector3(0.3,-0.1,0),rotationTangent:Vector3(0,0,0.2),
            angularVelocity:Vector3(0,0,-0.4),linearVelocity:Vector3(-0.2,0.5,0),angularAcceleration:Vector3(0,0,0.6),linearAcceleration:Vector3(0.8,-0.3,0)),
            FrameMotionDirection(translation:Vector3(-0.5,0.2,0),rotationTangent:Vector3(0,0,-0.1),
                angularVelocity:Vector3(0,0,0.3),linearVelocity:Vector3(0.4,-0.6,0),angularAcceleration:Vector3(0,0,-0.2),linearAcceleration:Vector3(-0.7,0.9,0))]
        return try make([body("root"),body("tip")],[j],q:[0.4],v:[0.7],a:[31],dq:[0.3],dv:[-0.2],da:[1.3],samples:samples,sampleDirections:directions)
    }
    static func policy(cancelled: Bool = false, maximumBodies: Int = 20) throws -> DerivativePolicy {
        try DerivativePolicy(maximumBodies:maximumBodies,maximumVelocities:20,maximumJacobianColumns:20,
            tolerance:NumericalTolerance(absolute:1e-8,relative:1e-10),residualTolerance:NumericalTolerance(absolute:1e-9,relative:1e-10),physicalNeighborhood:1e-3,
            inertiaValidation:InertiaValidationPolicy(symmetry:NumericalTolerance(absolute:0,relative:0),physicalityRelative:0),isCancelled:{ cancelled })
    }
    static func jointPolicy() throws -> JointEvaluationPolicy {
        try JointEvaluationPolicy(quaternionTolerance:NumericalTolerance(absolute:1e-12,relative:1e-12),chartRankRelative:1e-10,characteristicLengthMeters:1)
    }
    static func work(storage: Int = 1000000, operations: Int = 10000000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:100))
    }
    func tangent() throws -> TreeTangent {
        var scratch=TreeTangentWorkspace(), work=try Self.work(), supplier=try DerivativeSupplierWork(maximumCalls:100)
        let service:any TreeDifferentiating=ExactPlanarTreeDifferentiator()
        return try service.direction(tree,state:state,direction:direction,jointPolicy:Self.jointPolicy(),policy:Self.policy(),
            workspace:&scratch,supplierWork:&supplier,work:&work)
    }
    func shifted(_ h: Double) throws -> KinematicSnapshot {
        func add(_ x: [Double], _ d: [Double]) -> [Double] { zip(x,d).map { $0.0+h*$0.1 } }
        func vector(_ x: Vector3, _ d: Vector3) throws -> Vector3 { try x.adding(d.scaled(by:h)) }
        var samples:[PrescribedAnchorState]=[]
        for (sample,d) in zip(state.prescribedAnchors,direction.prescribed) {
            let m=sample.motion
            let rotation=try m.pose.rotation.multiplied(by:UnitQuaternion(axis:.unitZ,angle:h*d.rotationTangent.z))
            let motion=try FrameMotion(pose:RigidTransform(rotation:rotation,translation:vector(m.pose.translation,d.translation)),
                velocity:SpatialMotion(angular:vector(m.velocity.angular,d.angularVelocity),linear:vector(m.velocity.linear,d.linearVelocity)),
                acceleration:SpatialMotion(angular:vector(m.acceleration.angular,d.angularAcceleration),linear:vector(m.acceleration.linear,d.linearAcceleration)))
            samples.append(try PrescribedAnchorState(frame:sample.frame,time:state.time+h*direction.time,motion:motion))
        }
        return try TreeKinematicsEvaluator().evaluate(tree,state:KinematicState(revision:state.revision,time:state.time+h*direction.time,
            q:add(state.q,direction.configuration),v:add(state.v,direction.velocity),acceleration:add(state.acceleration,direction.acceleration),prescribedAnchors:samples),policy:Self.jointPolicy())
    }
    static func close(_ x: Double, _ y: Double, _ tolerance: Double = 2e-6) -> Bool { abs(x-y) <= tolerance*max(1,max(abs(x),abs(y))) }
}
