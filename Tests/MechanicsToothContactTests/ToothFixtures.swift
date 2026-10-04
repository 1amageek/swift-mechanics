import SwiftMechanics
import Foundation

enum ToothFixtures {
    static func id(_ kind: EntityKind,_ key: String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func work(operations: Int = 1_000_000_000, storage: Int = 2_000_000, calls: Int = 1_000_000) throws -> ToothContactWork {
        try ToothContactWork(budget:NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:1_000_000),maximumSupplierCalls:calls)
    }
    static func policy(mesh: Int = 1, maximumSteps: Int = 10_000, defect: Double = 1,
                       spacing: Double = 0.2, error: Double = 0.2,
                       cancelled: @escaping @Sendable () -> Bool = { false }) throws -> ToothContactPolicy {
        let tolerance=try NumericalTolerance(absolute:1e-10,relative:1e-10)
        return try ToothContactPolicy(maximumTeeth:2*mesh,maximumContacts:mesh*mesh,maximumIdentifierBytes:1_000_000,
            maximumSteps:maximumSteps,maximumFeatureSpacingMeters:spacing,maximumEnergyDefect:defect,physicalTolerance:1e-8,
            collision:CollisionQueryPolicy(absoluteLengthTolerance:1e-10,relativeLengthTolerance:1e-10,referenceLength:1,maximumApproximationError:error),
            contact:ContactAcceptancePolicy(absoluteEnergyTolerance:1e-9,absolutePowerTolerance:1e-9,relativeTolerance:1e-10,referenceEnergy:1,referencePower:1,coneTolerance:1e-10),
            dynamics:DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
                linearTolerance:LinearTolerance(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:1e-12),coordinateScales:[1,1],energyScale:1,timeScale:1),
            admission:DynamicsAdmission(capacity:DynamicsCapacity(maximumBodies:3,maximumVelocities:2,maximumBodyWrenches:2*mesh*mesh,maximumGeneralizedContributions:0),
                angularVelocityTolerance:tolerance,linearVelocityTolerance:tolerance),isCancelled:cancelled)
    }
    static func law(stiffness: Double, damping: Double = 0) throws -> ContactLawPair {
        func material(_ key: String) throws -> ContactMaterial {
            try ContactMaterial(reference:ModelReference(id:id(.material,key),revision:1),youngModulus:1e6,poissonsRatio:0.25,
                linearStiffness:2*stiffness,normalDamping:damping,huntCrossleyAlpha:0,friction:.none,
                resistance:ContactResistanceParameters(rollingCoefficient:0,spinningCoefficient:0,angularRegularization:0.1),cohesion:.none)
        }
        var work=ContactWork(budget:try ContactBudget(operations:100_000,scalarStorage:1000,records:1))
        return try SeriesContactPairing().combine(first:material("tooth-material-a"),second:material("tooth-material-b"),
            selection:.linear(maximumPenetration:0.8,maximumNormalSpeed:100),lossPolicy:.compliantDampingOnly,resistanceRadius:0.3,override:nil,work:&work)
    }
    static func model(mesh: Int = 1, inertia: Double = 1, damping: Double = 0, missingPair: Bool = false) throws -> ToothContactModel {
        let root=try body("root",position:.zero,moment:1,mode:.static)
        let a=try body("a",position:.zero,moment:inertia,mode:.dynamic)
        let b=try body("b",position:Vector3(2,0,0),moment:1,mode:.dynamic)
        let joints=try [hinge("b-joint",child:b.id,offset:Vector3(2,0,0)),hinge("a-joint",child:a.id,offset:.zero)]
        let tree=try KinematicTree(bodies:[b,root,a],joints:joints,root:root.id,rootBase:.fixed,
            worldFrame:id(.frame,"tooth-world"),revision:1,capacity:KinematicCapacity(maximumBodies:3,maximumVelocities:2,maximumJacobianScalars:36))
        let tolerance=try NumericalTolerance(absolute:1e-10,relative:1e-10)
        let jointPolicy=try JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-10,characteristicLengthMeters:1)
        let snapshot=try TreeKinematicsEvaluator().evaluate(tree,state:KinematicState(revision:1,time:0,q:[0,0],v:[0,0],acceleration:[0,0]),policy:jointPolicy)
        var teeth:[ToothProxyBinding]=[], inertias:[RigidBodyInertia]=[], drive=[Double](repeating:0,count:2)
        for body in tree.bodies {
            let moment=body.id == a.id ? inertia : 1
            inertias.append(try RigidBodyInertia(body:body.id,frame:body.frame,properties:properties(moment)))
        }
        for (side,body) in tree.bodies.dropFirst().enumerated() {
            let isA=body.id == a.id
            guard let layout=tree.layout.joints.first(where:{$0.joint == joints.first(where:{$0.childBody == body.id})!.id}) else { preconditionFailure("Missing actual layout.") }
            drive[layout.velocities.start]=isA ? -2 : -0.25
            for i in 0..<mesh {
                let z=mesh == 1 ? 0 : -0.05+(Double(i)+0.5)*0.1/Double(mesh)
                let local=try Vector3(isA ? 1 : -1,isA ? 0.25+0.4*z*z : -0.25-0.2*z*z,z)
                let placement=try RigidTransform(rotation:.identity,translation:local)
                let pose=try snapshot.body(body.id).motion.pose.composed(with:placement)
                let representation=try GeometryRepresentation(kind:.collisionGeometry,assetKey:"external-curved-tooth-\(side)-\(i)",
                    provenance:SourceProvenance(source:"external sampled curved flank",revision:1),quality:.approximation(maximumDeviationMeters:0.06/Double(mesh)))
                let proxy=try CollisionProxy(colliderID:id(.collider,"patch-\(side)-\(i)"),bodyID:body.id,frameID:tree.worldFrame,
                    geometryRevision:1,frameRevision:1,shape:.sphere(radius:0.3),margin:0,
                    representations:BodyRepresentations(collisionGeometry:representation),expectedSourceRevision:1,
                    resolution:.sampled(maximumFeatureSpacingMeters:0.1/Double(mesh)),pose:pose,
                    filter:ColliderFilter(enabled:true,layerBits:1,maskBits:1,isTrigger:false))
                teeth.append(ToothProxyBinding(toothID:UInt64(side*mesh+i+1),proxy:proxy,colliderToBody:placement))
            }
        }
        let pairLaw=try law(stiffness:10/Double(mesh*mesh),damping:damping)
        var contacts:[ToothContactPair]=[]
        for i in 0..<mesh { for j in 0..<mesh {
            if !missingPair || i != mesh-1 || j != mesh-1 { contacts.append(try ToothContactPair(key:"pair-\(i)-\(j)",firstProxy:i,secondProxy:mesh+j,law:pairLaw)) }
        } }
        var work=try work()
        return try ToothContactModel(source:SourceProvenance(source:"external curved tooth catalog",revision:1),tree:tree,referenceCoordinates:[0,0],
            inertias:inertias,teeth:teeth,contacts:contacts,driveForce:drive,jointPolicy:jointPolicy,policy:policy(mesh:mesh),work:&work)
    }
    private static func properties(_ moment: Double) throws -> MassProperties3D {
        try MassProperties3D(mass:1,centerOfMass:.zero,inertiaAtCenter:Matrix3(moment,0,0,0,moment,0,0,0,moment),
            policy:InertiaValidationPolicy(symmetry:NumericalTolerance(absolute:1e-10,relative:1e-10),physicalityRelative:0))
    }
    private static func body(_ key: String, position: Vector3, moment: Double, mode: BodyMotionMode) throws -> KinematicBody {
        KinematicBody(body:try BodyRecord3D(id:id(.body,"tooth-"+key),frame:id(.frame,"tooth-"+key+"-frame"),mode:mode,
            bodyToWorld:RigidTransform(rotation:.identity,translation:position),representations:BodyRepresentations(),
            inertia:InertialRepresentation3D(properties:properties(moment),provenance:SourceProvenance(source:"independent shaft inertia",revision:1),quality:.exact)))
    }
    private static func hinge(_ key: String, child: EntityID, offset: Vector3) throws -> JointRecord {
        try JointRecord(id:id(.joint,key),parentBody:id(.body,"tooth-root"),childBody:child,
            parentAnchor:JointAnchor(frame:id(.frame,key+"-parent"),placement:.fixed(RigidTransform(rotation:.identity,translation:offset))),
            childAnchor:JointAnchor(frame:id(.frame,key+"-child"),placement:.fixed(.identity)),manifold:JointManifold(.revolute(axis:.unitZ)))
    }
    static func indices(_ model: ToothContactModel) throws -> (Int,Int) {
        let a=try id(.joint,"a-joint"), b=try id(.joint,"b-joint")
        guard let x=model.tree.layout.joints.first(where:{$0.joint == a}),let y=model.tree.layout.joints.first(where:{$0.joint == b}) else { preconditionFailure("Missing actual layout.") }
        return (x.velocities.start,y.velocities.start)
    }
    static func initial(_ model: ToothContactModel, v: [Double] = [0,0]) throws -> ToothContactState {
        var work=try work()
        return try ReferenceToothContactEvolution(model:model).initial(time:0,q:[0,0],v:v,evaluationTimeStep:0.001,policy:policy(mesh:model.teeth.count/2),work:&work)
    }
    static func close(_ x: Double,_ y: Double, tolerance: Double = 1e-8) -> Bool { abs(x-y) <= tolerance*(1+abs(y)) }
}
