import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public enum CoSimulationQualificationFixtures {
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute:1e-9,relative:1e-10) }
    static func model(identity:String,mass:Double,q:Double,v:Double) throws -> CompiledMechanicalModel {
        let tol=try tolerance(),ip=try InertiaValidationPolicy(symmetry:tol,physicalityRelative:0),source=try SourceProvenance(source:"cosimulation-qualification",revision:1)
        let rootInertia=try InertialRepresentation3D(properties:MassProperties3D(mass:1,centerOfMass:.zero,inertiaAtCenter:.identity,policy:ip),provenance:source,quality:.exact)
        let childInertia=try InertialRepresentation3D(properties:MassProperties3D(mass:mass,centerOfMass:.zero,inertiaAtCenter:Matrix3(2,0,0,0,3,0,0,0,4),policy:ip),provenance:source,quality:.exact)
        let root=try BodyRecord3D(id:id(.body,identity+"-root"),frame:id(.frame,identity+"-root-frame"),mode:.static,bodyToWorld:.identity,representations:BodyRepresentations(),inertia:rootInertia)
        let child=try BodyRecord3D(id:id(.body,identity+"-carriage"),frame:id(.frame,identity+"-carriage-frame"),mode:.dynamic,bodyToWorld:RigidTransform(rotation:.identity,translation:Vector3(q,0,0)),representations:BodyRepresentations(),inertia:childInertia)
        let joint=try JointRecord(id:id(.joint,identity+"-rail"),parentBody:root.id,childBody:child.id,
            parentAnchor:JointAnchor(frame:id(.frame,identity+"-parent-anchor"),placement:.fixed(.identity)),childAnchor:JointAnchor(frame:id(.frame,identity+"-child-anchor"),placement:.fixed(.identity)),
            manifold:JointManifold(.prismatic(axis:.unitX)))
        let descriptor=try MechanicalDescriptor(identity:identity,revision:1,bodies:[.spatial(root),.spatial(child)],joints:[MechanicalJoint(record:joint,authority:.dynamicState)],
            root:root.id,rootBase:.fixed,rootAuthority:.fixed,worldFrame:id(.frame,identity+"-world"),initialState:KinematicState(revision:1,time:0,q:[q],v:[v],acceleration:[0]),representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:2,maximumVelocities:1,maximumJacobianScalars:12),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tol,chartRankRelative:1e-10,characteristicLengthMeters:1),inertiaPolicy:ip,
            translationTolerance:tol,rotationTolerance:tol,maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:1000,maximumDependencyEntries:1000,
            maximumExtensionRecords:8,maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:0),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }
    static func policy(cancel:@escaping @Sendable () -> Bool) throws -> ControlPolicy {
        let step=0.125, operations=10_000_000, scalars=100_000, actuation=100_000, bytes=16_384
        let maximumRate=1000.0, maximumPosition=1000.0, metadata=16_384
        let tol=try tolerance(),numerical=try NumericalBudget(scalarStorage:scalars,arithmeticOperations:operations,iterations:10000)
        let integration=try ExplicitIntegrationPolicy(method:.classicalRK4,initialStep:step*2,minimumStep:step*0.1,maximumStep:step*2,safety:0.8,minimumFactor:0.1,maximumFactor:2,
            scales:[ODEErrorScale(dimension:.length,absoluteSI:1e-9,relative:0),ODEErrorScale(dimension:PhysicalDimension(length:1,time:-1),absoluteSI:1e-9,relative:0)],maximumContinuationBytes:2048,
            budget:IntegrationBudget(maximumCoordinates:2,maximumAttempts:1,maximumAcceptedSteps:1,maximumOuterArithmetic:10000,supplier:numerical))
        return try ControlPolicy(maximumMetadataBytes:metadata,maximumGraphNodes:8,maximumGraphEdges:16,maximumPayloadBytes:bytes,
            maximumPositionMeters:maximumPosition,maximumRateMetersPerSecond:maximumRate,agreement:tol,
            actuation:ActuationBudget(maximumWork:actuation,maximumScalars:1000,maximumBytes:bytes,maximumBindings:2,maximumMetadataBytes:metadata,isCancelled:cancel),numerical:numerical,
            dynamics:DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),linearTolerance:LinearTolerance(absoluteResidual:1e-9,relativeResidual:1e-10,pivotThreshold:1e-12),coordinateScales:[2],energyScale:3,timeScale:0.7),
            admission:DynamicsAdmission(capacity:DynamicsCapacity(maximumBodies:2,maximumVelocities:1,maximumBodyWrenches:0,maximumGeneralizedContributions:2),angularVelocityTolerance:tol,linearVelocityTolerance:tol,isCancelled:cancel),
            inertia:InertiaValidationPolicy(symmetry:tol,physicalityRelative:0),integration:integration,
            runtimeCapacity:RuntimeCapacity(maximumPhysicalScalars:3,maximumContributors:3,maximumContributorBytes:8192,maximumMetadataBytes:8192,maximumCheckpointBytes:16384,
                maximumValidationWork:100000,maximumValidationScratchBytes:8192,maximumObservationLeases:2,maximumBatchStates:1,maximumTransactions:10000,maximumStepWorkUnits:100_000,maximumWorkBetweenSafePoints:1),
            continuation:RuntimeContinuationIdentity(build:"cosimulation-original-rk4-v1",backend:"referenceCPU",precision:"float64"),isCancelled:cancel)
    }
    public static func configuration(identity:String,mass:Double,q:Double,v:Double,disturbance:Double,
                                     effortLimit:Double=100,gate:CoSimulationQualificationGate?=nil) throws -> CoSimulationParticipantConfiguration {
        let model=try Self.model(identity:identity,mass:mass,q:q,v:v)
        let policy=try Self.policy(cancel:{ gate?.poll() ?? false })
        let binding=try ActuatorBinding(actuator:id(.actuator,identity+"-drive"),joint:id(.joint,identity+"-rail"),
            frame:model.descriptor.worldFrame,model:model.stamp,lawRevision:1,continuationKey:44,
            positionIndex:0,velocityIndex:0,coordinate:.translation,authority:.dynamicState,stateKind:.servo,
            stateDomain:ActuatorScalarDomain(primaryLower:-10,primaryUpper:10,secondaryLower:-1000,secondaryUpper:1000))
        let servo=try ScalarServo(binding:binding,positionGain:4,velocityGain:2,integralGain:0,integralLimit:10,
            effortLimit:effortLimit,speedLimit:1000,positionDeadband:0,velocityDeadband:0,filterTimeConstant:0)
        let port=try ScalarControlPort(binding:binding,parentAnchorFrame:id(.frame,identity+"-parent-anchor"))
        var work=NumericalWork(budget:policy.numerical)
        let plant=try PrismaticControlPlant(model:model,port:port,disturbanceNewtons:disturbance,policy:policy,work:&work)
        let controller=SampledController(servo:servo,mode:.effort)
        let actuator=try ActuatorState(binding:binding,time:0,primary:0,secondary:0,mode:.effort,sequence:0)
        return try CoSimulationParticipantConfiguration(identity:identity,maximumIdentityBytes:256,plant:plant,controller:controller,
            clock:ControlClock(epochSeconds:0,periodSeconds:0.125,maximumTimeSeconds:1,maximumTicks:8),
            initialActuator:actuator,seed:42,control:policy,
            observation:ObservationPolicy(maximumBodies:2,maximumCoordinates:1,maximumReactionRows:0,maximumMetadataBytes:16_384),
            encoderBudget:policy.numerical)
    }
    public static func coupling(stiffness:Double=4,damping:Double=0.5,absoluteEnergy:Double=0.05,
                                exchange:CoSimulationCoupling.Exchange = .held,delay:Double=0) throws -> CoSimulationCoupling {
        try CoSimulationCoupling(stiffnessNewtonsPerMeter:stiffness,dampingNewtonSecondsPerMeter:damping,restOffsetMeters:0,
            exchange:exchange,delaySeconds:delay,energyAgreement:NumericalTolerance(absolute:absoluteEnergy,relative:1e-10),
            forceAgreement:NumericalTolerance(absolute:1e-9,relative:1e-10),powerAgreement:NumericalTolerance(absolute:1e-9,relative:1e-10),
            maximumAccumulatedAbsoluteEnergyDefectJoules:1)
    }
    public static func budget(macros:UInt64=8) throws -> CoSimulationBudget {
        try CoSimulationBudget(numerical:NumericalBudget(scalarStorage:200_000,arithmeticOperations:1_000_000_000,iterations:1_000_000),
            maximumActuationWork:100_000_000,maximumValidationWork:100_000_000,maximumCodecByteCapacity:10_000_000,
            maximumRetainedCheckpointBytes:32_768,maximumMacros:macros)
    }
    public static func make(first:CoSimulationParticipantConfiguration,second:CoSimulationParticipantConfiguration,
                            coupling:CoSimulationCoupling,budget:CoSimulationBudget) throws -> any CoSimulationOperating {
        let factory:any CoSimulationCreating=ReferenceCoSimulationFactory()
        return try factory.make(first:first,second:second,coupling:coupling,budget:budget)
    }
    static func demand(_ condition:Bool,_ name:String) throws {
        guard condition else { throw CoSimulationQualificationError.oracle(name) }
    }
    static func close(_ actual:Double,_ expected:Double,_ name:String) throws {
        try demand(actual.isFinite && expected.isFinite && abs(actual-expected) <= 1e-9*max(1,abs(expected)),name)
    }
    static func failure(_ name:String,_ body:() throws -> Void) throws -> CoSimulationFailure {
        do { try body() } catch let failure as CoSimulationFailure { return failure }
        throw CoSimulationQualificationError.unexpectedSuccess(name)
    }
    static func unchanged(_ actual:CoSimulationBoundary,_ expected:CoSimulationBoundary,_ name:String) throws {
        try demand(actual.first.accepted == expected.first.accepted && actual.second.accepted == expected.second.accepted,name)
    }
}
