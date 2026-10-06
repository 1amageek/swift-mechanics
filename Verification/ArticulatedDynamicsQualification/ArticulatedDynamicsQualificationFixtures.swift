import SwiftMechanics

public enum ArticulatedDynamicsQualificationFixtures {
    public static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind:kind,key:"aba-qualification-"+key) }
    public static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute:1e-10,relative:1e-10) }
    public static func mass(_ value: Double, _ center: Vector3 = .zero, tensor: Matrix3 = .identity) throws -> MassProperties3D {
        try MassProperties3D(mass:value,centerOfMass:center,inertiaAtCenter:tensor,
            policy:InertiaValidationPolicy(symmetry:tolerance(),physicalityRelative:0))
    }
    public static func body(_ name: String, _ mass: MassProperties3D, pose: RigidTransform = .identity) throws -> KinematicBody {
        KinematicBody(body:try BodyRecord3D(id:id(.body,name),frame:id(.frame,name+"-frame"),mode:.dynamic,bodyToWorld:pose,
            representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:mass,
                provenance:SourceProvenance(source:"synthetic-analytical-aba-qualification",revision:1),quality:.exact)))
    }
    public static func joint(_ name: String, parent: KinematicBody, child: KinematicBody, specification: JointSpecification,
                             anchor: RigidTransform = .identity) throws -> JointRecord {
        try JointRecord(id:id(.joint,name),parentBody:parent.id,childBody:child.id,
            parentAnchor:JointAnchor(frame:id(.frame,name+"-parent"),placement:.fixed(anchor)),
            childAnchor:JointAnchor(frame:id(.frame,name+"-child"),placement:.fixed(.identity)),manifold:JointManifold(specification))
    }
    public static func input(bodies: [KinematicBody], joints: [JointRecord], masses: [MassProperties3D], q: [Double], v: [Double],
                             suppliedAcceleration: [Double]? = nil, rootBase: BaseLayout = .fixed,
                             gravity: AffineGravity? = nil, bodyLoads: [BodyWrenchContribution] = [],
                             generalized: [GeneralizedForceContribution] = []) throws -> RigidDynamicsInput {
        guard !bodies.isEmpty, bodies.count==masses.count else { throw ArticulatedDynamicsQualificationError.assertion("fixture body/inertia shape") }
        let tree=try KinematicTree(bodies:bodies,joints:joints,root:bodies[0].id,rootBase:rootBase,worldFrame:id(.frame,"world"),
            revision:1,capacity:KinematicCapacity(maximumBodies:8,maximumVelocities:8,maximumJacobianScalars:384))
        let snapshot=try TreeKinematicsEvaluator().evaluate(tree,state:KinematicState(revision:1,time:0,q:q,v:v,
            acceleration:suppliedAcceleration ?? [Double](repeating:0,count:v.count)),
            policy:JointEvaluationPolicy(quaternionTolerance:tolerance(),chartRankRelative:1e-10,characteristicLengthMeters:1))
        var inertias:[RigidBodyInertia]=[]
        for b in tree.bodies {
            guard let index=bodies.firstIndex(where:{$0.id==b.id}) else { throw ArticulatedDynamicsQualificationError.assertion("original body order mapping") }
            inertias.append(try RigidBodyInertia(body:b.id,frame:b.frame,properties:masses[index]))
        }
        return try RigidDynamicsInput(snapshot:snapshot,velocity:v,inertias:inertias,gravity:gravity,
            bodyWrenches:bodyLoads,generalizedForces:generalized)
    }
    public static func policy(_ coordinates: Int, scales: [Double]? = nil, energy: Double = 1, time: Double = 1,
                              pivot: Double = 1e-12, bodies: Int = 8, complete: Bool = true,
                              cancelled: @escaping @Sendable () -> Bool = {false}) throws -> ArticulatedDynamicsPolicy {
        try ArticulatedDynamicsPolicy(admission:DynamicsAdmission(capacity:DynamicsCapacity(maximumBodies:bodies,maximumVelocities:8,
            maximumBodyWrenches:8,maximumGeneralizedContributions:8),angularVelocityTolerance:tolerance(),
            linearVelocityTolerance:tolerance(),isCancelled:cancelled),coordinateScales:scales ?? [Double](repeating:1,count:coordinates),
            energyScale:energy,timeScale:time,pivotThreshold:pivot,originalResidualTolerance:tolerance(),powerTolerance:tolerance(),
            requireCompleteEnergy:complete)
    }
    public static func work(operations: Int = 2_000_000, scalars: Int = 100_000, iterations: Int = 1000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:scalars,arithmeticOperations:operations,iterations:iterations))
    }
    public static func loads(limit: Int = 10000) throws -> LoadWork { LoadWork(budget:try LoadBudget(maximumWork:limit,maximumScalars:1000)) }
    public static func pendulum(gravity: Bool = false, damping: Bool = false) throws -> RigidDynamicsInput {
        let rm=try mass(1), cm=try mass(2,.unitX), root=try body("pendulum-root",rm), child=try body("pendulum-child",cm)
        let hinge=try joint("pendulum-hinge",parent:root,child:child,specification:.revolute(axis:.unitZ))
        let field=gravity ? try AffineGravity(frame:id(.frame,"world"),accelerationAtOrigin:Vector3(0,-10,0)) : nil
        var known:[GeneralizedForceContribution]=[]
        if damping {
            var work=try loads()
            let response=try ScalarLoadEvaluator().evaluate(PolynomialSpringDamper(coordinateKind:.rotation,restCoordinate:0,
                quadraticStiffness:2,linearDamping:3,maximumDisplacement:1,maximumRate:3),coordinate:0,rate:2,work:&work)
            known.append(try GeneralizedForceContribution(values:[response.total()],channel:.applied,
                potentialEnergy:response.potentialEnergy,dissipatedPower:response.dissipatedPower))
        }
        return try input(bodies:[root,child],joints:[hinge],masses:[rm,cm],q:[0],v:[2],suppliedAcceleration:[99],gravity:field,generalized:known)
    }
    public static func serialHinges(generalized: [GeneralizedForceContribution] = []) throws -> RigidDynamicsInput {
        let rm=try mass(1), a=try mass(2,.unitX), b=try mass(3,.unitX,tensor:Matrix3(2,0,0,0,2,0,0,0,2))
        let root=try body("serial-root",rm), first=try body("serial-first",a), second=try body("serial-second",b)
        let one=try joint("serial-one",parent:root,child:first,specification:.revolute(axis:.unitZ))
        let two=try joint("serial-two",parent:first,child:second,specification:.revolute(axis:.unitZ),
            anchor:RigidTransform(rotation:.identity,translation:Vector3(2,0,0)))
        return try input(bodies:[root,first,second],joints:[one,two],masses:[rm,a,b],q:[0,Double.pi/2],v:[1,2],
            suppliedAcceleration:[77,-31],generalized:generalized)
    }
}
