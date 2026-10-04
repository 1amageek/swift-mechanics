import SwiftMechanics
import Foundation

struct PlanarDynamicsFixtures {
    static func properties(_ mass:Double,_ x:Double = 0,_ y:Double = 0,_ polar:Double = 1) throws -> MassProperties2D {
        try MassProperties2D(mass:mass,centerX:x,centerY:y,polarInertiaAtCenter:polar)
    }
    static func body(_ key:String,_ properties:MassProperties2D,mode:BodyMotionMode = .dynamic) throws -> KinematicBody {
        try KinematicBody(body:try BodyRecord2D(id:DynamicsFixtures.id(.body,key),frame:DynamicsFixtures.id(.frame,key+"-frame"),mode:mode,
            bodyToWorld:PlanarPose(x:0,y:0,angle:0),representations:BodyRepresentations(),
            inertia:InertialRepresentation2D(properties:properties,provenance:SourceProvenance(source:"original-planar",revision:1),quality:.exact)))
    }
    static func inertia(_ key:String,_ properties:MassProperties2D) throws -> PlanarRigidBodyInertia {
        try PlanarRigidBodyInertia(body:DynamicsFixtures.id(.body,key),frame:DynamicsFixtures.id(.frame,key+"-frame"),properties:properties)
    }
    static func free(gravity:AffineGravity? = nil,loads:[BodyWrenchContribution] = [],velocity:[Double] = [0.7,-0.4,1.1]) throws -> PlanarRigidDynamicsInput {
        let p=try properties(3,0.4,-0.3,1.2)
        let snapshot=try DynamicsFixtures.snapshot(bodies:[body("free-plane",p)],joints:[],root:"free-plane",base:.planarFloating,
            q:[1,-2,0.6],v:velocity,acceleration:[9,8,7])
        return try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:velocity,inertias:[inertia("free-plane",p)],gravity:gravity,bodyWrenches:loads)
    }
    static func gravity(_ y:Double = -9) throws -> AffineGravity {
        try AffineGravity(frame:DynamicsFixtures.id(.frame,"world"),accelerationAtOrigin:Vector3(0,y,0))
    }
    static func pendulum(prescribed:Bool = false,loads:[BodyWrenchContribution] = []) throws -> PlanarRigidDynamicsInput {
        let root=try properties(1),child=try properties(2,0.6,0.2,0.7)
        let hinge=try DynamicsFixtures.hinge("planar-hinge",parent:"plane-root",child:"plane-bob",parentPlacement:prescribed ? .prescribed : .fixed(.identity))
        let samples=prescribed ? [try PrescribedAnchorState(frame:hinge.parentAnchor.frame,time:0,
            motion:FrameMotion(pose:.identity,velocity:SpatialMotion(angular:.zero,linear:Vector3(4,0,0)),
                acceleration:SpatialMotion(angular:.zero,linear:Vector3(3,0,0))))] : []
        let snapshot=try DynamicsFixtures.snapshot(bodies:[body("plane-root",root,mode:.static),body("plane-bob",child)],joints:[hinge],root:"plane-root",
            q:[0.4],v:[0.7],acceleration:[99],anchors:samples)
        return try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:[0.7],inertias:[inertia("plane-root",root),inertia("plane-bob",child)],gravity:gravity(-10),bodyWrenches:loads)
    }
    static func twoLink(acceleration:[Double] = [99,-17]) throws -> PlanarRigidDynamicsInput {
        let root=try properties(1),first=try properties(2,0.7,0,1),second=try properties(3,0.8,0,0.9)
        let hinge1=try DynamicsFixtures.hinge("plane-first-joint",parent:"plane-root",child:"plane-first")
        let hinge2=try DynamicsFixtures.hinge("plane-second-joint",parent:"plane-first",child:"plane-second",
            parentPlacement:.fixed(RigidTransform(rotation:.identity,translation:Vector3(2,0,0))))
        let snapshot=try DynamicsFixtures.snapshot(bodies:[body("plane-root",root,mode:.static),body("plane-first",first),body("plane-second",second)],
            joints:[hinge1,hinge2],root:"plane-root",q:[0.3,-0.6],v:[0.8,-0.4],acceleration:acceleration)
        return try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:[0.8,-0.4],inertias:[inertia("plane-root",root),inertia("plane-first",first),inertia("plane-second",second)],gravity:gravity(-10))
    }
    static func assemble(_ input:PlanarRigidDynamicsInput,work:inout NumericalWork) throws -> PhysicalRigidDynamicsSystem {
        var loadWork=try DynamicsFixtures.loadWork()
        let equations:any PhysicalRigidEquationComputing=RigidEquationKernel()
        return try equations.assemble(PhysicalRigidDynamicsInput(planar:input),admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work)
    }
    static func solver() -> any PhysicalRigidDynamicsSolving { DenseRigidDynamics(physicalEquations:RigidEquationKernel()) }
}
