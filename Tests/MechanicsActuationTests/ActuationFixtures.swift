import MechanicsActuation
import MechanicsCore
import MechanicsModel
import MechanicsLoads
import MechanicsNumerics
import MechanicsJoints
import MechanicsCompiler
import MechanicsRuntime

enum ActuationFixtures {
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute:1e-10,relative:1e-11) }
    static func budget(work:Int=10000,scalars:Int=100,bytes:Int=4096,bindings:Int=16,metadata:Int=1000,cancelled:Bool=false) throws -> ActuationBudget {
        try ActuationBudget(maximumWork:work,maximumScalars:scalars,maximumBytes:bytes,maximumBindings:bindings,maximumMetadataBytes:metadata,isCancelled:{ cancelled })
    }
    static func work() throws -> ActuationWork { ActuationWork(budget:try budget()) }
    static func numerical(operations:Int=10000,storage:Int=100) throws -> NumericalWork { NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:0)) }
    static func binding(kind:ActuatorStateKind = .servo,coordinate:ScalarCoordinateKind = .rotation,revision:UInt64=1,lawRevision:UInt64=1,key:UInt64=99,
                        authority:CoordinateAuthority = .dynamicState) throws -> ActuatorBinding {
        let domain:ActuatorScalarDomain
        switch kind {
        case .servo:domain=try ActuatorScalarDomain(primaryLower:-10,primaryUpper:10,secondaryLower:-1000,secondaryUpper:1000)
        case .motor:domain=try ActuatorScalarDomain(primaryLower:-100,primaryUpper:100,secondaryLower:0,secondaryUpper:0)
        case .fluid:domain=try ActuatorScalarDomain(primaryLower:0,primaryUpper:100,secondaryLower:0,secondaryUpper:0)
        case .muscle:domain=try ActuatorScalarDomain(primaryLower:0,primaryUpper:1,secondaryLower:0,secondaryUpper:0)
        }
        return try ActuatorBinding(actuator:id(.actuator,"drive"),joint:id(.joint,"joint"),frame:id(.frame,"world"),model:ModelStamp(identity:"actuation-model",revision:revision),
            lawRevision:lawRevision,continuationKey:key,positionIndex:0,velocityIndex:0,coordinate:coordinate,authority:authority,stateKind:kind,stateDomain:domain)
    }
    static func servo(_ binding:ActuatorBinding?=nil,gain:Double=4,velocityGain:Double=2,integralGain:Double=2,effort:Double=3,speed:Double=10,filter:Double=0) throws -> ScalarServo {
        try ScalarServo(binding:binding ?? self.binding(),positionGain:gain,velocityGain:velocityGain,integralGain:integralGain,integralLimit:10,
            effortLimit:effort,speedLimit:speed,positionDeadband:0.01,velocityDeadband:0.01,filterTimeConstant:filter)
    }
    static func sample(_ binding:ActuatorBinding,time:Double=0,position:Double=0,velocity:Double=0) throws -> ActuatorSample {
        try ActuatorSample(binding:binding,time:time,position:position,velocity:velocity)
    }
    static func state(_ binding:ActuatorBinding,time:Double=0,primary:Double=0,secondary:Double=0,mode:DriveMode = .effort,sequence:UInt64=0) throws -> ActuatorState {
        try ActuatorState(binding:binding,time:time,primary:primary,secondary:secondary,mode:mode,sequence:sequence)
    }
    static func model(revision:UInt64=1,authority:CoordinateAuthority = .dynamicState,translation:Bool=false) throws -> CompiledMechanicalModel {
        let tolerance=try self.tolerance(),inertiaPolicy=try InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0)
        let source=try SourceProvenance(source:"actuation-fixture",revision:1)
        let inertia=try InertialRepresentation3D(properties:MassProperties3D(mass:1,centerOfMass:.zero,inertiaAtCenter:.identity,policy:inertiaPolicy),provenance:source,quality:.exact)
        let root=try BodyRecord3D(id:id(.body,"root"),frame:id(.frame,"root-frame"),mode:.static,bodyToWorld:.identity,representations:BodyRepresentations(),inertia:nil)
        let child=try BodyRecord3D(id:id(.body,"child"),frame:id(.frame,"child-frame"),mode:authority == .prescribedMotion ? .prescribedKinematic : .dynamic,
            bodyToWorld:.identity,representations:BodyRepresentations(),inertia:inertia)
        let record=try JointRecord(id:id(.joint,"joint"),parentBody:root.id,childBody:child.id,parentAnchor:JointAnchor(frame:id(.frame,"parent-anchor"),placement:.fixed(.identity)),
            childAnchor:JointAnchor(frame:id(.frame,"child-anchor"),placement:.fixed(.identity)),manifold:JointManifold(translation ? .prismatic(axis:.unitX) : .revolute(axis:.unitZ)))
        let state=try KinematicState(revision:revision,time:0,q:[0],v:[0],acceleration:[0])
        let descriptor=try MechanicalDescriptor(identity:"actuation-model",revision:revision,bodies:[.spatial(root),.spatial(child)],joints:[MechanicalJoint(record:record,authority:authority)],
            root:root.id,rootBase:.fixed,rootAuthority:.fixed,worldFrame:id(.frame,"world"),initialState:state,representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:8,maximumVelocities:16,maximumJacobianScalars:384),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-9,characteristicLengthMeters:1),inertiaPolicy:inertiaPolicy,
            translationTolerance:tolerance,rotationTolerance:tolerance,maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:1000,maximumDependencyEntries:1000,
            maximumExtensionRecords:8,maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:0),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }
    static func registry(_ binding:ActuatorBinding) throws -> ActuatorRuntimeContributors {
        var work=try self.work();return try ActuatorRuntimeContributors(bindings:[binding],codec:FixedActuatorContinuationCodec(),controlBudget:budget(),work:&work)
    }
}
