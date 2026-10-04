import SwiftMechanics

internal enum PlanarReactionFixtures {
    static func body(_ key:String,_ properties:MassProperties2D,mode:BodyMotionMode = .dynamic,x:Double=0,angle:Double=0) throws->KinematicBody {
        try KinematicBody(body:BodyRecord2D(id:ReactionFixtures.id(.body,key),frame:ReactionFixtures.id(.frame,key+"-frame"),mode:mode,
            bodyToWorld:PlanarPose(x:x,y:0,angle:angle),representations:BodyRepresentations(),
            inertia:InertialRepresentation2D(properties:properties,provenance:SourceProvenance(source:"planar-reaction-original",revision:7),quality:.exact)))
    }
    static func inertia(_ key:String,_ properties:MassProperties2D) throws->PlanarRigidBodyInertia {
        try PlanarRigidBodyInertia(body:ReactionFixtures.id(.body,key),frame:ReactionFixtures.id(.frame,key+"-frame"),properties:properties)
    }
    static func gravity(_ y:Double = -10) throws->AffineGravity {
        try AffineGravity(frame:ReactionFixtures.id(.frame,"world"),accelerationAtOrigin:Vector3(0,y,0))
    }
    static func pendulum(theta:Double=0,speed:Double=1,loads:[BodyWrenchContribution]=[]) throws->PlanarRigidDynamicsInput {
        let root=try MassProperties2D(mass:1,centerX:0,centerY:0,polarInertiaAtCenter:1)
        let bob=try MassProperties2D(mass:2,centerX:1,centerY:0,polarInertiaAtCenter:4)
        let joint=try ReactionFixtures.hinge("plane-hinge",parent:"plane-root",child:"plane-bob")
        let snapshot=try ReactionFixtures.snapshot(bodies:[body("plane-root",root,mode:.static),body("plane-bob",bob)],joints:[joint],root:"plane-root",
            q:[theta],v:[speed],acceleration:[99])
        return try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:[speed],inertias:[inertia("plane-root",root),inertia("plane-bob",bob)],gravity:gravity(),bodyWrenches:loads)
    }
    static func slider(mass:Double=2,prescribedY:Double=0,gravity:Bool=false,generalized:Bool=false) throws->PlanarRigidDynamicsInput {
        let root=try MassProperties2D(mass:1,centerX:0,centerY:0,polarInertiaAtCenter:1)
        let first=try MassProperties2D(mass:mass,centerX:0,centerY:0,polarInertiaAtCenter:1)
        let joint=try JointRecord(id:ReactionFixtures.id(.joint,"plane-slide"),parentBody:ReactionFixtures.id(.body,"plane-root"),childBody:ReactionFixtures.id(.body,"plane-first"),
            parentAnchor:JointAnchor(frame:ReactionFixtures.id(.frame,"plane-slide-parent"),placement:prescribedY == 0 ? .fixed(.identity) : .prescribed),
            childAnchor:JointAnchor(frame:ReactionFixtures.id(.frame,"plane-slide-child"),placement:.fixed(.identity)),manifold:JointManifold(.prismatic(axis:.unitX)))
        let samples=prescribedY == 0 ? [] : [try PrescribedAnchorState(frame:joint.parentAnchor.frame,time:0,
            motion:FrameMotion(pose:.identity,velocity:FrameMotion.zeroMotion,acceleration:SpatialMotion(angular:.zero,linear:Vector3(0,prescribedY,0))))]
        let snapshot=try ReactionFixtures.snapshot(bodies:[body("plane-root",root,mode:.static),body("plane-first",first)],joints:[joint],root:"plane-root",q:[0],v:[0],acceleration:[0],anchors:samples)
        let drives=generalized ? [try GeneralizedForceContribution(values:[1],channel:.actuator)] : []
        return try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:[0],inertias:[inertia("plane-root",root),inertia("plane-first",first)],
            gravity:gravity ? Self.gravity() : nil,generalizedForces:drives)
    }
    static func offsetSliders() throws->PlanarRigidDynamicsInput {
        let root=try MassProperties2D(mass:1,centerX:0,centerY:0,polarInertiaAtCenter:1)
        let first=try MassProperties2D(mass:2,centerX:0,centerY:0,polarInertiaAtCenter:1)
        let second=try MassProperties2D(mass:3,centerX:0,centerY:0,polarInertiaAtCenter:1)
        var joints:[JointRecord]=[]
        for (i,key) in ["plane-first","plane-second"].enumerated() {
            let angle:Double=i == 0 ? -.pi/2 : 0
            let parent=i == 0 ? "plane-root" : "plane-first"
            let parentPose:RigidTransform=i == 0 ? .identity : try RigidTransform(rotation:UnitQuaternion(axis:.unitZ,angle:-.pi/2),translation:.zero)
            joints.append(try JointRecord(id:ReactionFixtures.id(.joint,key+"-slide"),parentBody:ReactionFixtures.id(.body,parent),childBody:ReactionFixtures.id(.body,key),
                parentAnchor:JointAnchor(frame:ReactionFixtures.id(.frame,key+"-parent"),placement:.fixed(parentPose)),
                childAnchor:JointAnchor(frame:ReactionFixtures.id(.frame,key+"-child"),placement:.fixed(RigidTransform(rotation:UnitQuaternion(axis:.unitZ,angle:angle),translation:.zero))),
                manifold:JointManifold(.prismatic(axis:.unitX))))
        }
        let snapshot=try ReactionFixtures.snapshot(bodies:[body("plane-root",root,mode:.static),body("plane-first",first,angle:.pi/2),body("plane-second",second,x:2)],
            joints:joints,root:"plane-root",q:[0,2],v:[0,0],acceleration:[0,0])
        // First body Rz(pi/2) maps local (5,-10) at local X to world (10,5) at world Y.
        let load=try BodyWrenchContribution(body:ReactionFixtures.id(.body,"plane-first"),frame:ReactionFixtures.id(.frame,"plane-first-frame"),referencePoint:.unitX,
            wrench:SpatialWrench(torque:.zero,force:Vector3(5,-10,0)),channel:.applied)
        return try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:[0,0],inertias:[inertia("plane-root",root),inertia("plane-first",first),inertia("plane-second",second)],gravity:gravity(),bodyWrenches:[load])
    }
    static func floating() throws->PlanarRigidDynamicsInput {
        let mass=try MassProperties2D(mass:2,centerX:0,centerY:0,polarInertiaAtCenter:1)
        let snapshot=try ReactionFixtures.snapshot(bodies:[body("plane-free",mass)],joints:[],root:"plane-free",base:.planarFloating,q:[0,0,0],v:[0,0,0],acceleration:[0,0,0])
        return try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:[0,0,0],inertias:[inertia("plane-free",mass)],gravity:gravity())
    }
    static func system(_ input:PlanarRigidDynamicsInput) throws->PhysicalRigidDynamicsSystem {
        var work=try ReactionFixtures.work(),loads=try ReactionFixtures.loadWork()
        let equations:any PhysicalRigidEquationComputing=RigidEquationKernel()
        return try equations.assemble(PhysicalRigidDynamicsInput(planar:input),admission:ReactionFixtures.admission(),loadWork:&loads,work:&work)
    }
    static func policy(_ n:Int,cancelled:Bool=false,bodies:Int=10) throws->TreeReactionPolicy {
        let tolerance=try NumericalTolerance(absolute:1e-9,relative:1e-10)
        return try TreeReactionPolicy(maximumBodies:bodies,maximumJoints:10,maximumBodyLoads:20,generalizedForceScales:[Double](repeating:1,count:n),
            generalizedTolerance:tolerance,forceTolerance:tolerance,torqueTolerance:tolerance,isCancelled:{cancelled})
    }
}
