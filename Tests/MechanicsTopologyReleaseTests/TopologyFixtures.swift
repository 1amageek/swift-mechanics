import SwiftMechanics

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
enum TopologyFixtures {
    typealias Session = RuntimeSession<TopologyCheckpointHandler>
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func work() throws -> NumericalWork { NumericalWork(budget:try NumericalBudget(scalarStorage:2_000_000,arithmeticOperations:100_000_000,iterations:100_000)) }
    static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute:1e-8,relative:1e-8) }
    static func policy(cancelled:Bool=false) throws -> SubtreeReleasePolicy {
        let t=try tolerance()
        return try SubtreeReleasePolicy(maximumBodies:8,maximumCoordinates:64,translation:t,rotation:t,linearVelocity:t,
            angularVelocity:t,kineticEnergy:t,linearMomentum:t,angularMomentum:t,isCancelled:{cancelled})
    }
    static func admission() throws -> DynamicsAdmission {
        DynamicsAdmission(capacity:try DynamicsCapacity(maximumBodies:8,maximumVelocities:32,maximumBodyWrenches:8,maximumGeneralizedContributions:8),angularVelocityTolerance:try tolerance(),linearVelocityTolerance:try tolerance())
    }
    static func dynamics(_ count:Int) throws -> DynamicsSolvePolicy {
        try DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:LinearTolerance(absoluteResidual:1e-8,relativeResidual:1e-8,pivotThreshold:1e-12),
            coordinateScales:[Double](repeating:1,count:count),energyScale:1,timeScale:1)
    }
    static func actuationBudget() throws -> ActuationBudget {
        try ActuationBudget(maximumWork:100000,maximumScalars:1000,maximumBytes:16384,maximumBindings:16,maximumMetadataBytes:4096)
    }
    static func historyPolicy(events:Int=4,bytes:Int=16384) throws -> TopologyContinuationPolicy {
        try TopologyContinuationPolicy(maximumEvents:events,maximumBytes:bytes,maximumMetadataBytes:4096,maximumWork:100000)
    }
    static func model(floating:Bool=false) throws -> CompiledMechanicalModel {
        let t=try tolerance(),ip=try InertiaValidationPolicy(symmetry:t,physicalityRelative:0)
        let rootPose=RigidTransform(rotation:try UnitQuaternion(axis:.unitZ,angle:0.4),translation:try Vector3(2,-1,0.5))
        var bodies:[MechanicalBody]=[]
        for (index,key) in ["root","A","B","C"].enumerated() {
            let properties=try MassProperties3D(mass:Double(index+1),centerOfMass:Vector3(0.1,-0.15,0.05),
                inertiaAtCenter:Matrix3(1.2,0,0,0,0.9,0,0,0,1.1),policy:ip)
            bodies.append(.spatial(try BodyRecord3D(id:id(.body,key),frame:id(.frame,key+"-body"),mode:index == 0 && !floating ? .static : .dynamic,
                bodyToWorld:index == 0 ? rootPose : .identity,representations:BodyRepresentations(),
                inertia:InertialRepresentation3D(properties:properties,provenance:SourceProvenance(source:"topology-oracle",revision:1),quality:.exact))))
        }
        var joints:[MechanicalJoint]=[]
        for i in 0..<3 {
            let key="j\(i+1)",names=["root","A","B","C"]
            let parent=RigidTransform(rotation:try UnitQuaternion(axis:i == 1 ? .unitX : .unitZ,angle:0.1*Double(i+1)),translation:try Vector3(0.4,0.1,0.2))
            let child=RigidTransform(rotation:try UnitQuaternion(axis:.unitY,angle:-0.2),translation:try Vector3(0.2,-0.1,0.05))
            let spec:JointSpecification = i == 2 ? .prismatic(axis:.unitX) : .revolute(axis:i == 1 ? .unitY : .unitZ)
            joints.append(MechanicalJoint(record:try JointRecord(id:id(.joint,key),parentBody:id(.body,names[i]),childBody:id(.body,names[i+1]),
                parentAnchor:JointAnchor(frame:id(.frame,key+"-parent"),placement:.fixed(parent)),
                childAnchor:JointAnchor(frame:id(.frame,key+"-child"),placement:.fixed(child)),manifold:JointManifold(spec)),authority:.dynamicState))
        }
        let r=rootPose.rotation
        let rootQ=floating ? [rootPose.translation.x,rootPose.translation.y,rootPose.translation.z,-r.w,-r.x,-r.y,-r.z] : []
        let q=rootQ+[0.3,-0.4,0.25],v=(floating ? [0.7,-0.2,0.4,0.3,-0.1,0.2] : [])+[1.1,-0.6,0.8]
        let a=(floating ? [0.1,0.2,-0.1,-0.2,0.3,0.1] : [])+[0.2,-0.3,0.15]
        let state=try KinematicState(revision:1,time:0,q:q,v:v,acceleration:a)
        let capacity=try KinematicCapacity(maximumBodies:8,maximumVelocities:32,maximumJacobianScalars:4096)
        let jointPolicy=try JointEvaluationPolicy(quaternionTolerance:t,chartRankRelative:1e-10,characteristicLengthMeters:1)
        let tree=try KinematicTree(bodies:bodies.map { try $0.kinematicBody() },joints:joints.map { $0.record },root:id(.body,"root"),rootBase:floating ? .spatialFloating : .fixed,
            worldFrame:id(.frame,"world"),revision:1,capacity:capacity)
        let snapshot=try TreeKinematicsEvaluator().evaluate(tree,state:state,policy:jointPolicy)
        bodies=try bodies.map { body in
            guard case .spatial(let record)=body else { throw TopologyReleaseFailure.invalidInput }
            return .spatial(try BodyRecord3D(id:record.id,frame:record.frame,mode:record.mode,bodyToWorld:snapshot.body(record.id).motion.pose,
                representations:record.representations,inertia:record.inertia))
        }
        let descriptor=try MechanicalDescriptor(identity:"subtree-system",revision:1,bodies:bodies,joints:joints,root:id(.body,"root"),
            rootBase:floating ? .spatialFloating : .fixed,rootAuthority:floating ? .dynamicState : .fixed,worldFrame:id(.frame,"world"),initialState:state,
            representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:capacity,jointPolicy:jointPolicy,inertiaPolicy:ip,translationTolerance:t,rotationTolerance:t,
            maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:10000,maximumDependencyEntries:10000,maximumExtensionRecords:4,maximumDiagnostics:8,
            extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }
    static func catalog(_ model:CompiledMechanicalModel,policy:TopologyContinuationPolicy?=nil) throws -> TopologyEventCatalog {
        let rules=try [rule(1,joint:"j2",root:"B",connector:"release-one"),rule(2,joint:"j1",root:"A",connector:"release-two")]
        return try TopologyEventCatalog(initialModel:model.stamp,initialTime:0,initialSequence:0,rules:rules,policy:policy ?? historyPolicy())
    }
    static func rule(_ n:UInt64,joint:String,root:String,connector:String,metric:TopologyReleaseMetric = .explicitRelease,threshold:Double=0) throws -> TopologyReleaseRule {
        try TopologyReleaseRule(id:n,joint:id(.joint,joint),connector:id(.joint,connector),parentAnchor:id(.frame,connector+"-parent"),
            childAnchor:id(.frame,connector+"-child"),subtreeRoot:id(.body,root),metric:metric,threshold:threshold)
    }
    static func release(_ model:CompiledMechanicalModel,state:CompiledKinematicState?=nil,rule:TopologyReleaseRule) throws -> SubtreeRelease {
        var w=try work(),d=try work()
        return try ReferenceSubtreeReleaseBuilder().release(model:model,state:state ?? model.makeState(model.descriptor.initialState),joint:rule.joint,connector:rule.connector,
            parentAnchor:rule.parentAnchor,childAnchor:rule.childAnchor,policy:policy(),admission:admission(),work:&w,dynamicsWork:&d)
    }
    static func reconcile(_ release:SubtreeRelease) throws -> ReconciledSubtreeRelease {
        var w=try work(),l=LoadWork(budget:try LoadBudget(maximumWork:100000,maximumScalars:100000))
        return try ReferenceSubtreeAccelerationPreparer().prepare(release,gravity:AffineGravity(frame:release.target.descriptor.worldFrame,accelerationAtOrigin:Vector3(0,-9.81,0)),
            bodyWrenches:[],generalizedForces:[],drive:[Double](repeating:0,count:release.target.tree.layout.velocityCount),admission:admission(),
            policy:dynamics(release.target.tree.layout.velocityCount),work:&w,loadWork:&l)
    }
    static func binding(_ model:CompiledMechanicalModel) throws -> ActuatorBinding {
        let joint=try id(.joint,"j3")
        guard let range=model.tree.layout.joints.first(where: { $0.joint == joint }) else { throw TopologyReleaseFailure.invalidInput }
        return try ActuatorBinding(actuator:id(.actuator,"C-servo"),joint:range.joint,frame:model.descriptor.worldFrame,model:model.stamp,lawRevision:3,continuationKey:19,
            positionIndex:range.positions.start,velocityIndex:range.velocities.start,coordinate:.translation,authority:.dynamicState,stateKind:.servo,
            stateDomain:ActuatorScalarDomain(primaryLower:-10,primaryUpper:10,secondaryLower:-1000,secondaryUpper:1000))
    }
    static func capacity() throws -> RuntimeCapacity {
        try RuntimeCapacity(maximumPhysicalScalars:256,maximumContributors:8,maximumContributorBytes:65536,maximumMetadataBytes:10000,maximumCheckpointBytes:131072,
            maximumValidationWork:200000,maximumValidationScratchBytes:65536,maximumObservationLeases:2,maximumBatchStates:2,maximumTransactions:1000,
            maximumStepWorkUnits:100000,maximumWorkBetweenSafePoints:4)
    }
    static func configuration(_ schemas:[RuntimeContributorSchema]) throws -> RuntimeConfiguration {
        try RuntimeConfiguration(continuation:RuntimeContinuationIdentity(build:"topology-tests",backend:"reference-cpu",precision:"float64"),
            requiredContributors:schemas,capacity:capacity(),determinism:.sameBuildReplay,workload:"subtree-release")
    }
    static func session(_ model:CompiledMechanicalModel,integrator:Bool=false) throws -> (Session,TopologyHistoryContributor,ActuatorBinding) {
        let h=try TopologyHistoryContributor(model:model,catalog:catalog(model),policy:historyPolicy()),b=try binding(model)
        var a=ActuationWork(budget:try actuationBudget())
        let p=try ActuatorRuntimeContributors(bindings:[b],codec:FixedActuatorContinuationCodec(),controlBudget:actuationBudget(),work:&a)
        let record=try FixedActuatorContinuationCodec().encode(ActuatorState(binding:b,time:0,primary:0.4,secondary:-0.7,mode:.position,sequence:8),work:&a)
        var providers:[any RuntimeContributorHandling]=[h,p],records=[h.record,record]
        if integrator {
            let eq=try TopologyReadbackEquation(model:model),provider=try integration(eq)
            providers.append(provider);records.append(try provider.initialRecord(physical:model.descriptor.initialState,equations:eq))
        }
        let registry=try TopologyRuntimeContributors(providers:providers,capacity:capacity()),config=try configuration(registry.schemas)
        let handler=TopologyCheckpointHandler(history:h,contributors:registry)
        return (try Session(model:model,configuration:config,initialState:model.descriptor.initialState,contributors:records,seed:42,checkpoints:handler),h,b)
    }
    static func integration(_ equation:TopologyReadbackEquation) throws -> IntegrationContinuationProvider {
        let scales=try equation.descriptor.dimensions.map { try ODEErrorScale(dimension:$0,absoluteSI:1e-6,relative:1e-6) }
        let policy=try ExplicitIntegrationPolicy(method:.classicalRK4,initialStep:0.01,minimumStep:1e-6,maximumStep:0.1,safety:0.8,minimumFactor:0.1,maximumFactor:2,
            scales:scales,maximumContinuationBytes:16384,budget:IntegrationBudget(maximumCoordinates:128,maximumAttempts:10,maximumAcceptedSteps:10,
                maximumOuterArithmetic:100000,supplier:work().budget))
        return try IntegrationContinuationProvider(descriptor:equation.descriptor,policy:policy)
    }
    static func prepare(_ session:Session,history:TopologyHistoryContributor,binding:ActuatorBinding,rule:TopologyReleaseRule,integrator:Bool=false) throws -> PreparedTopologyPublication {
        let release=try release(history.model,state:session.snapshot().physical,rule:rule),target=try reconcile(release)
        var dispositions:[TopologyContributorDisposition]=[.appendHistory,.migrateScalarActuator(binding:binding,controlBudget:try actuationBudget())]
        var schemas=history.schemas+session.configuration.requiredContributors.filter { $0.category == .actuator }
        if integrator {
            let eq=try TopologyReadbackEquation(model:release.target),provider=try integration(eq)
            dispositions.append(.initializeIntegration(retiredID:provider.schema.id,provider:provider,equations:eq));schemas+=provider.schemas
        }
        var w=try work(),a=ActuationWork(budget:try actuationBudget())
        return try ReferenceTopologyTransitionPreparer().prepare(source:session.snapshot(),sourceConfiguration:session.configuration,transition:target,history:history,
            observation:.explicit(release),ruleID:rule.id,dispositions:dispositions,targetConfiguration:configuration(schemas),work:&w,actuationWork:&a)
    }
}
