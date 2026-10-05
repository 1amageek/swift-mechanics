import SwiftMechanics
import Testing
import Synchronization

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
struct ControlFixtures {
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute:1e-9,relative:1e-10) }
    static func work(operations:Int=10000000,storage:Int=100000,iterations:Int=10000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations))
    }
    static func model(q:Double=0,v:Double=0,time:Double=0,translation:Bool=true,com:Vector3 = .zero,axis:Vector3 = .unitX) throws -> CompiledMechanicalModel {
        let tol=try tolerance(),ip=try InertiaValidationPolicy(symmetry:tol,physicalityRelative:0),source=try SourceProvenance(source:"control-test",revision:1)
        let rootInertia=try InertialRepresentation3D(properties:MassProperties3D(mass:1,centerOfMass:.zero,inertiaAtCenter:.identity,policy:ip),provenance:source,quality:.exact)
        let childInertia=try InertialRepresentation3D(properties:MassProperties3D(mass:2,centerOfMass:com,inertiaAtCenter:Matrix3(2,0,0,0,3,0,0,0,4),policy:ip),provenance:source,quality:.exact)
        let root=try BodyRecord3D(id:id(.body,"root"),frame:id(.frame,"root-frame"),mode:.static,bodyToWorld:.identity,representations:BodyRepresentations(),inertia:rootInertia)
        let child=try BodyRecord3D(id:id(.body,"carriage"),frame:id(.frame,"carriage-frame"),mode:.dynamic,bodyToWorld:.identity,representations:BodyRepresentations(),inertia:childInertia)
        let joint=try JointRecord(id:id(.joint,"rail"),parentBody:root.id,childBody:child.id,
            parentAnchor:JointAnchor(frame:id(.frame,"parent-anchor"),placement:.fixed(.identity)),childAnchor:JointAnchor(frame:id(.frame,"child-anchor"),placement:.fixed(.identity)),
            manifold:JointManifold(translation ? .prismatic(axis:axis):.revolute(axis:.unitZ)))
        let descriptor=try MechanicalDescriptor(identity:"control-model",revision:1,bodies:[.spatial(root),.spatial(child)],joints:[MechanicalJoint(record:joint,authority:.dynamicState)],
            root:root.id,rootBase:.fixed,rootAuthority:.fixed,worldFrame:id(.frame,"world"),initialState:KinematicState(revision:1,time:time,q:[q],v:[v],acceleration:[0]),representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:2,maximumVelocities:1,maximumJacobianScalars:12),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tol,chartRankRelative:1e-10,characteristicLengthMeters:1),inertiaPolicy:ip,
            translationTolerance:tol,rotationTolerance:tol,maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:1000,maximumDependencyEntries:1000,
            maximumExtensionRecords:8,maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:0),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }
    static func policy(step:Double=0.1,operations:Int=10000000,scalars:Int=100000,actuation:Int=100000,bytes:Int=4096,
                       maximumRate:Double=1000,maximumPosition:Double=1000,metadata:Int=10000,cancel:@escaping @Sendable () -> Bool = {false}) throws -> ControlPolicy {
        let tol=try tolerance(),numerical=try NumericalBudget(scalarStorage:scalars,arithmeticOperations:operations,iterations:10000)
        let integration=try ExplicitIntegrationPolicy(method:.classicalRK4,initialStep:step*2,minimumStep:step*0.1,maximumStep:step*2,safety:0.8,minimumFactor:0.1,maximumFactor:2,
            scales:[ODEErrorScale(dimension:.length,absoluteSI:1e-9,relative:0),ODEErrorScale(dimension:PhysicalDimension(length:1,time:-1),absoluteSI:1e-9,relative:0)],maximumContinuationBytes:2048,
            budget:IntegrationBudget(maximumCoordinates:2,maximumAttempts:1,maximumAcceptedSteps:1,maximumOuterArithmetic:10000,supplier:numerical))
        return try ControlPolicy(maximumMetadataBytes:metadata,maximumGraphNodes:8,maximumGraphEdges:16,maximumPayloadBytes:bytes,
            maximumPositionMeters:maximumPosition,maximumRateMetersPerSecond:maximumRate,agreement:tol,
            actuation:ActuationBudget(maximumWork:actuation,maximumScalars:1000,maximumBytes:bytes,maximumBindings:2,maximumMetadataBytes:metadata,isCancelled:cancel),numerical:numerical,
            dynamics:DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),linearTolerance:LinearTolerance(absoluteResidual:1e-9,relativeResidual:1e-10,pivotThreshold:1e-12),coordinateScales:[2],energyScale:3,timeScale:0.7),
            admission:DynamicsAdmission(capacity:DynamicsCapacity(maximumBodies:2,maximumVelocities:1,maximumBodyWrenches:0,maximumGeneralizedContributions:0),angularVelocityTolerance:tol,linearVelocityTolerance:tol,isCancelled:cancel),
            inertia:InertiaValidationPolicy(symmetry:tol,physicalityRelative:0),integration:integration,
            runtimeCapacity:RuntimeCapacity(maximumPhysicalScalars:3,maximumContributors:3,maximumContributorBytes:8192,maximumMetadataBytes:8192,maximumCheckpointBytes:16384,
                maximumValidationWork:100000,maximumValidationScratchBytes:8192,maximumObservationLeases:2,maximumBatchStates:1,maximumTransactions:10000,maximumStepWorkUnits:100,maximumWorkBetweenSafePoints:1),
            continuation:RuntimeContinuationIdentity(build:"control-test",backend:"referenceCPU",precision:"float64"),isCancelled:cancel)
    }
    static func plant(model:CompiledMechanicalModel?=nil,policy:ControlPolicy?=nil,disturbance:Double=0,mode:DriveMode = .effort,
                      kp:Double=4,kv:Double=2,ki:Double=0,effort:Double=100,speed:Double=1000,filter:Double=0) throws -> (PrismaticControlPlant,ScalarServo,ControlPolicy) {
        let m=try model ?? self.model(),p=try policy ?? self.policy()
        let binding=try ActuatorBinding(actuator:id(.actuator,"drive"),joint:id(.joint,"rail"),frame:m.descriptor.worldFrame,model:m.stamp,lawRevision:1,continuationKey:44,
            positionIndex:0,velocityIndex:0,coordinate:.translation,authority:.dynamicState,stateKind:.servo,
            stateDomain:ActuatorScalarDomain(primaryLower:-10,primaryUpper:10,secondaryLower:-10000,secondaryUpper:10000))
        let port=try ScalarControlPort(binding:binding,parentAnchorFrame:id(.frame,"parent-anchor")),law=try ScalarServo(binding:binding,positionGain:kp,velocityGain:kv,integralGain:ki,integralLimit:10,
            effortLimit:effort,speedLimit:speed,positionDeadband:0,velocityDeadband:0,filterTimeConstant:filter)
        var work=try self.work()
        return (try PrismaticControlPlant(model:m,port:port,disturbanceNewtons:disturbance,policy:p,work:&work),law,p)
    }
    static func session(plant:PrismaticControlPlant,law:ScalarServo,policy:ControlPolicy,mode:DriveMode = .effort,computed:Bool=false,period:Double=0.1,
                        initialIntegral:Double=0,factory:any ControlSessionCreating = ReferenceControlSessionFactory()) throws -> any ControlSessionOperating {
        let controller=try computed ? SampledController(effortServo:law,positionAccelerationGain:4,rateAccelerationGain:2):SampledController(servo:law,mode:mode)
        let state=try ActuatorState(binding:law.binding,time:plant.model.descriptor.initialState.time,primary:initialIntegral,secondary:0,mode:computed ? .effort:mode,sequence:0)
        var work=try self.work()
        return try factory.make(plant:plant,controller:controller,clock:ControlClock(epochSeconds:state.time,periodSeconds:period,maximumTimeSeconds:1000,maximumTicks:10000),
            initialActuator:state,seed:42,policy:policy,work:&work)
    }
    static func observation(_ session:any ControlSessionOperating) throws -> ControlObservation {
        let capture=ControlTestCapture()
        try session.observe { value throws(ControlFailure) in capture.store(value) }
        return try #require(capture.read())
    }
    static func input(_ session:any ControlSessionOperating,plant:PrismaticControlPlant,value:Double=3,mode:DriveMode = .effort,computed:ComputedTorqueReference?=nil,
                      timeOffset:Double=0,tickOffset:UInt64=0,dimension:PhysicalDimension?=nil) throws -> ControlSampleInput {
        let observation=try self.observation(session)
        var work=try self.work()
        let p=try ObservationPolicy(maximumBodies:2,maximumCoordinates:1,maximumReactionRows:0,maximumMetadataBytes:10000)
        let source=try ReferenceObservationSourcePreparer().prepare(model:plant.model,state:observation.accepted.physical,solved:nil,policy:p,work:&work)
        let encoder=try ReferenceKinematicObserver().encoder(source:source,joint:plant.port.binding.joint,policy:p,work:&work)
        let units:PhysicalDimension
        if computed != nil { units=PhysicalDimension(length:1,time:-2) }
        else { switch mode { case .effort:units=plant.port.effortDimension;case .position:units = .length;case .velocity:units=plant.port.rateDimension } }
        let demand:ControlSampleInput.Demand
        if let computed { demand = .computedTorque(computed) } else { demand = .servo(try DriveCommand(mode:mode,value:value)) }
        return ControlSampleInput(encoder:encoder,sampleTickTime:observation.accepted.checkpoint.physical.time+timeOffset,tick:observation.controller.tick+tickOffset,
            demand:demand,commandDimension:dimension ?? units)
    }
    static func close(_ a:Double,_ b:Double) -> Bool { abs(a-b) <= 1e-8*max(1,abs(b)) }
    static func failure(_ body:() throws -> Void) throws -> ControlFailure {
        do { try body();Issue.record("Expected control refusal");throw Unexpected.success } catch let error as ControlFailure { return error }
    }
    enum Unexpected:Error { case success }
}
