import SwiftMechanics

public struct WheeledAssembliesQualificationFixture: Sendable {
    public let model: CompiledMechanicalModel
    public let configuration: WheeledAssemblyConfiguration
    public let state: WheeledAssemblyState
    public let assembly: ReferenceWheeledAssembly
    public let positions, velocities: [Int]

    public static func tolerance(_ absolute: Double = 1e-10) throws -> NumericalTolerance {
        try NumericalTolerance(absolute:absolute,relative:absolute)
    }
    public static func id(_ kind: EntityKind, _ key: String) throws -> EntityID {
        try EntityID(kind:kind,key:"wheeled-qualification-"+key)
    }
    public static func work(steps: Int = 8, calls: Int = 100, cancelled: Bool = false) throws -> WheeledAssemblyWork {
        try WheeledAssemblyWork(maximumSteps:steps,maximumModelCalls:calls,
            numerical:NumericalWork(budget:NumericalBudget(scalarStorage:100_000,arithmeticOperations:2_000_000,iterations:1000)),
            loads:LoadWork(budget:LoadBudget(maximumWork:100_000,maximumScalars:1000,isCancelled:{cancelled})),
            actuation:ActuationWork(budget:ActuationBudget(maximumWork:100_000,maximumScalars:1000,maximumBytes:100_000,
                maximumBindings:100,maximumMetadataBytes:100_000,isCancelled:{cancelled})))
    }
    public static func implementation(_ dynamics: any RigidDynamicsSolving = DenseRigidDynamics()) -> ReferenceWheeledAssembly {
        ReferenceWheeledAssembly(equations:RigidEquationKernel(),dynamics:dynamics,loads:ScalarLoadEvaluator(),
            drive:ReferenceDriveEvaluator(),transmission:ReferenceActuationTransmitter(mapper:LoadMapper()))
    }
    public init(rootPosition: Vector3 = .zero, rootVelocity: Vector3 = .zero, gravityZ: Double = 0,
                suspension: [Double] = [0,0], suspensionRates: [Double] = [0,0], spins: [Double] = [0,0]) throws {
        guard suspension.count==2, suspensionRates.count==2, spins.count==2 else {
            throw WheeledAssembliesQualificationError.assertion("fixture coordinate shape")
        }
        let t=try WheeledAssemblyTopology(chassis:Self.id(.body,"chassis"),rearCarrier:Self.id(.body,"rear-carrier"),
            rearWheel:Self.id(.body,"rear-wheel"),frontCarrier:Self.id(.body,"front-carrier"),frontKnuckle:Self.id(.body,"front-knuckle"),
            frontWheel:Self.id(.body,"front-wheel"),rearSuspension:Self.id(.joint,"rear-suspension"),
            frontSuspension:Self.id(.joint,"front-suspension"),rearSpin:Self.id(.joint,"rear-spin"),
            steering:Self.id(.joint,"steering"),frontSpin:Self.id(.joint,"front-spin"))
        let bodyIDs=[t.chassis,t.rearCarrier,t.rearWheel,t.frontCarrier,t.frontKnuckle,t.frontWheel]
        let masses=[10.0,2,1,1,1,1], centers=[0.0,-1,-1,1,1,1]
        let ip=try InertiaValidationPolicy(symmetry:Self.tolerance(),physicalityRelative:0)
        let source=try SourceProvenance(source:"synthetic-analytical-six-body",revision:1)
        var bodies:[MechanicalBody]=[]
        for i in bodyIDs.indices {
            let tensor=i==0 ? try Matrix3(10,0,0,0,10,0,0,0,10) : .identity
            let properties=try MassProperties3D(mass:masses[i],centerOfMass:.zero,inertiaAtCenter:tensor,policy:ip)
            let inertia=try InertialRepresentation3D(properties:properties,provenance:source,quality:.exact)
            bodies.append(.spatial(try BodyRecord3D(id:bodyIDs[i],frame:Self.id(.frame,"body-"+String(i)),mode:.dynamic,
                bodyToWorld:RigidTransform(rotation:.identity,translation:Vector3(centers[i],0,0)),representations:BodyRepresentations(),inertia:inertia)))
        }
        let jointIDs=[t.rearSuspension,t.frontSuspension,t.rearSpin,t.steering,t.frontSpin]
        let parents=[t.chassis,t.chassis,t.rearCarrier,t.frontCarrier,t.frontKnuckle]
        let children=[t.rearCarrier,t.frontCarrier,t.rearWheel,t.frontKnuckle,t.frontWheel]
        var joints:[MechanicalJoint]=[]
        for i in jointIDs.indices {
            let placement=try RigidTransform(rotation:.identity,translation:Vector3(i==0 ? -1 : i==1 ? 1 : 0,0,0))
            let specification:JointSpecification=i<2 ? .prismatic(axis:.unitZ) : .revolute(axis:i==3 ? .unitZ : .unitY)
            let record=try JointRecord(id:jointIDs[i],parentBody:parents[i],childBody:children[i],
                parentAnchor:JointAnchor(frame:Self.id(.frame,"parent-"+String(i)),placement:.fixed(placement)),
                childAnchor:JointAnchor(frame:Self.id(.frame,"child-"+String(i)),placement:.fixed(.identity)),manifold:JointManifold(specification))
            joints.append(MechanicalJoint(record:record,authority:.dynamicState))
        }
        let original=try KinematicState(revision:1,time:0,q:[0,0,0,1,0,0,0,0,0,0,0,0],v:[Double](repeating:0,count:11),
            acceleration:[Double](repeating:0,count:11))
        let descriptor=try MechanicalDescriptor(identity:"six-body-analytical-wheeled",revision:1,bodies:bodies,joints:joints,
            root:t.chassis,rootBase:.spatialFloating,rootAuthority:.dynamicState,worldFrame:Self.id(.frame,"world"),initialState:original,
            representationRequirements:[],features:[],extensions:[])
        let cp=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:8,maximumVelocities:16,maximumJacobianScalars:768),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:Self.tolerance(),chartRankRelative:1e-10,characteristicLengthMeters:1),
            inertiaPolicy:ip,translationTolerance:Self.tolerance(),rotationTolerance:Self.tolerance(),maximumRecords:100,
            maximumIdentifierBytes:100_000,maximumSparsityEntries:10_000,maximumDependencyEntries:10_000,
            maximumExtensionRecords:8,maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:1000,arithmeticOperations:10000,iterations:0),target:.nativeCPU)
        let model=try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:cp)
        var positions:[Int]=[], velocities:[Int]=[]
        for id in jointIDs {
            guard let layout=model.tree.layout.joints.first(where:{$0.joint==id}),layout.positions.count==1,layout.velocities.count==1 else {
                throw WheeledAssembliesQualificationError.assertion("original canonical scalar layout")
            }
            positions.append(layout.positions.start);velocities.append(layout.velocities.start)
        }
        var q=original.q, v=original.v
        q[0]=rootPosition.x;q[1]=rootPosition.y;q[2]=rootPosition.z
        v[0]=rootVelocity.x;v[1]=rootVelocity.y;v[2]=rootVelocity.z
        for i in 0..<2 {q[positions[i]]=suspension[i];v[velocities[i]]=suspensionRates[i]}
        v[velocities[2]]=spins[0];v[velocities[4]]=spins[1]
        let compiled=try model.makeState(KinematicState(revision:1,time:0,q:q,v:v,acceleration:[Double](repeating:0,count:11)))
        let binding=try ActuatorBinding(actuator:Self.id(.actuator,"steer"),joint:t.steering,frame:model.tree.worldFrame,model:model.stamp,
            lawRevision:1,continuationKey:7,positionIndex:positions[3],velocityIndex:velocities[3],coordinate:.rotation,authority:.dynamicState,
            stateKind:.servo,stateDomain:ActuatorScalarDomain(primaryLower:-10,primaryUpper:10,secondaryLower:-1,secondaryUpper:1))
        let servo=try ScalarServo(binding:binding,positionGain:20,velocityGain:0,integralGain:0,integralLimit:10,
            effortLimit:100,speedLimit:100,positionDeadband:0,velocityDeadband:0,filterTimeConstant:0)
        let steering=try ActuatorState(binding:binding,time:0,primary:0,mode:.position)
        var transmissionWork=try Self.work().actuation;var gradient=[Double](repeating:0,count:11);gradient[velocities[2]]=1
        var kinds=[ScalarCoordinateKind](repeating:.rotation,count:11)
        for i in [0,1,2,velocities[0],velocities[1]] {kinds[i] = .translation}
        let transmission=try AffineTransmission(model:model.stamp,frame:model.tree.worldFrame,outputCoordinate:.rotation,
            inputCoordinates:kinds,gradient:gradient,prescribedRate:0,work:&transmissionWork)
        let solve=try DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:LinearTolerance(absoluteResidual:1e-9,relativeResidual:1e-10,pivotThreshold:1e-12),
            coordinateScales:[Double](repeating:1,count:11),energyScale:1,timeScale:1)
        let p=try WheeledAssemblyPolicy(maximumTimeStep:0.1,maximumSteeringAngle:0.5,maximumRoadForce:1000,maximumRoadTorque:1000,
            maximumRoadLeverArm:10,maximumCumulativeEnergyDefect:1e-6,maximumWheelSpin:100,maximumRootLinearSpeed:100,maximumRootAngularSpeed:100,
            powerTolerance:Self.tolerance(),energyTolerance:Self.tolerance(1e-9),linearMomentumTolerance:Self.tolerance(1e-9),
            angularMomentumTolerance:Self.tolerance(1e-9),dynamicsAdmission:DynamicsAdmission(capacity:DynamicsCapacity(maximumBodies:8,
                maximumVelocities:16,maximumBodyWrenches:8,maximumGeneralizedContributions:8),angularVelocityTolerance:Self.tolerance(),
                linearVelocityTolerance:Self.tolerance()),dynamicsSolve:solve)
        let law=try PolynomialSpringDamper(coordinateKind:.translation,restCoordinate:0,quadraticStiffness:100,linearDamping:5,
            maximumDisplacement:1,maximumRate:20)
        let c=try WheeledAssemblyConfiguration(model:model,topology:t,calibration:source,rearSuspensionLaw:law,frontSuspensionLaw:law,
            steeringServo:servo,driveline:transmission,maximumShaftEffort:26,maximumRearBrakeTorque:4,maximumFrontBrakeTorque:4,
            gravity:AffineGravity(frame:model.tree.worldFrame,accelerationAtOrigin:Vector3(0,0,gravityZ)),policy:p)
        let assembly=Self.implementation();var work=try Self.work()
        self.state=try assembly.initialize(configuration:c,state:compiled,steering:steering,work:&work)
        self.model=model;self.configuration=c;self.assembly=assembly;self.positions=positions;self.velocities=velocities
    }
    public func road(rear: Vector3 = .zero, front: Vector3 = .zero, time: Double = 0, validUntil: Double = 1,
                     frame: EntityID? = nil) throws -> WheeledAssemblyRoadInput {
        let snapshot=try model.evaluate(state.kinematic)
        let r=try snapshot.body(configuration.topology.rearWheel).motion.pose.translation
        let f=try snapshot.body(configuration.topology.frontWheel).motion.pose.translation
        return try WheeledAssemblyRoadInput(source:SourceProvenance(source:"synthetic-explicit-held-road-wrenches",revision:1),time:time,validUntil:validUntil,
            rear:BodyWrenchContribution(body:configuration.topology.rearWheel,frame:frame ?? model.tree.worldFrame,referencePoint:r,
                wrench:SpatialWrench(torque:.zero,force:rear),channel:.contact),
            front:BodyWrenchContribution(body:configuration.topology.frontWheel,frame:frame ?? model.tree.worldFrame,referencePoint:f,
                wrench:SpatialWrench(torque:.zero,force:front),channel:.contact))
    }
    public static func driver(throttle: Double = 0, steering: Double = 0, rearBrake: Double = 0, frontBrake: Double = 0) throws -> WheeledAssemblyDriver {
        try WheeledAssemblyDriver(throttle:throttle,steeringAngle:steering,rearBrake:rearBrake,frontBrake:frontBrake)
    }
}
