import SwiftMechanics

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal enum SleepTopologyFixtures {
    typealias Session=RuntimeSession<TopologyCheckpointHandler>
    final class Source: Sendable {
        let model:CompiledMechanicalModel
        let owner:CheckpointedMechanismSleep
        let history:TopologyHistoryContributor
        let handler:TopologyCheckpointHandler
        let session:Session
        init(model:CompiledMechanicalModel,owner:CheckpointedMechanismSleep,history:TopologyHistoryContributor,handler:TopologyCheckpointHandler,session:Session) {
            self.model=model;self.owner=owner;self.history=history;self.handler=handler;self.session=session
        }
    }
    final class Selection: Sendable {
        let retirement:PreparedSleepTopologyRetirement
        let transition:NonlinearReconciledSubtreeRelease
        let equations:NonlinearMechanismEquation
        let continuation:IntegrationContinuationProvider
        let history:TopologyHistoryContributor
        let wake:SleepTopologyWakeContributor
        let prepared:PreparedSleepTopologyPublication
        init(retirement:PreparedSleepTopologyRetirement,transition:NonlinearReconciledSubtreeRelease,equations:NonlinearMechanismEquation,
             continuation:IntegrationContinuationProvider,history:TopologyHistoryContributor,wake:SleepTopologyWakeContributor,prepared:PreparedSleepTopologyPublication) {
            self.retirement=retirement;self.transition=transition;self.equations=equations;self.continuation=continuation;self.history=history;self.wake=wake;self.prepared=prepared
        }
    }
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func work(operations:Int = 100_000_000,storage:Int = 2_000_000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:100_000))
    }
    static func model(mass:Double = 2) throws -> CompiledMechanicalModel {
        let tolerance=try NumericalTolerance(absolute:1e-10,relative:1e-10),ip=try InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0)
        var bodies:[MechanicalBody]=[],joints:[MechanicalJoint]=[]
        for key in ["root","a","b","c"] {
            let properties=try MassProperties3D(mass:key == "c" ? mass : 2,centerOfMass:.zero,inertiaAtCenter:Matrix3(1,0,0,0,1,0,0,0,1),policy:ip)
            bodies.append(.spatial(try BodyRecord3D(id:id(.body,key),frame:id(.frame,key+"-body"),mode:key == "root" ? .static : .dynamic,
                bodyToWorld:.identity,representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:properties,
                    provenance:SourceProvenance(source:"sleep-topology-oracle",revision:1),quality:.exact))))
            if key != "root" {
                joints.append(MechanicalJoint(record:try JointRecord(id:id(.joint,key),parentBody:id(.body,"root"),childBody:id(.body,key),
                    parentAnchor:JointAnchor(frame:id(.frame,key+"-parent"),placement:.fixed(.identity)),
                    childAnchor:JointAnchor(frame:id(.frame,key+"-child"),placement:.fixed(.identity)),manifold:JointManifold(.prismatic(axis:.unitY))),authority:.dynamicState))
            }
        }
        let initial=try KinematicState(revision:1,time:0,q:[0,0,0],v:[0,0,0],acceleration:[0,0,0])
        let descriptor=try MechanicalDescriptor(identity:"sleep-topology-three-sliders",revision:1,bodies:[bodies[3],bodies[0],bodies[2],bodies[1]],joints:joints,
            root:id(.body,"root"),rootBase:.fixed,rootAuthority:.fixed,worldFrame:id(.frame,"world"),initialState:initial,representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:8,maximumVelocities:32,maximumJacobianScalars:20000),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-10,characteristicLengthMeters:1),inertiaPolicy:ip,
            translationTolerance:tolerance,rotationTolerance:tolerance,maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:10000,
            maximumDependencyEntries:10000,maximumExtensionRecords:8,maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }
    static func admission() throws -> DynamicsAdmission {
        DynamicsAdmission(capacity:try DynamicsCapacity(maximumBodies:8,maximumVelocities:32,maximumBodyWrenches:0,maximumGeneralizedContributions:0),
            angularVelocityTolerance:try NumericalTolerance(absolute:1e-10,relative:1e-10),linearVelocityTolerance:try NumericalTolerance(absolute:1e-10,relative:1e-10))
    }
    static func equation(_ model:CompiledMechanicalModel,target:Bool = false,energy:Double = 1,effort:Double = -4,
                         solver:any ConstrainedMechanismSolving = MassWeightedMechanismSolver(),cancelled:@escaping @Sendable () -> Bool = {false}) throws -> NonlinearMechanismEquation {
        let p=model.tree.layout.positionCount,n=model.tree.layout.velocityCount,revision=model.stamp.revision
        var qIDs=(0..<p).map {UInt64(901+$0)},vIDs=(0..<n).map {UInt64(901+$0)}
        var qDimensions=[PhysicalDimension](repeating:.length,count:p),vDimensions=[PhysicalDimension](repeating:.length,count:n)
        for entry in model.tree.layout.joints {
            if entry.positions.count == 7 {
                for i in 3..<7 { qDimensions[entry.positions.start+i] = .dimensionless }
                for i in 3..<6 { vDimensions[entry.velocities.start+i] = .angle }
            } else {
                let value:UInt64=entry.joint.key == "a" ? 101 : entry.joint.key == "b" ? 102 : 103
                qIDs[entry.positions.start]=value;vIDs[entry.velocities.start]=value
            }
        }
        let q=try ConstraintCoordinateLayout(coordinateIDs:qIDs,dimensions:qDimensions,scales:[Double](repeating:1,count:p),timeScale:1,revision:revision)
        let v=try ConstraintCoordinateLayout(coordinateIDs:vIDs,dimensions:vDimensions,scales:[Double](repeating:1,count:n),timeScale:1,revision:revision)
        func entry(_ key:String) throws -> JointCoordinateLayout {
            guard let value=model.tree.layout.joints.first(where:{$0.joint.key == key}) else { throw TopologyReleaseFailure.invalidInput };return value
        }
        var rows:[QuadraticConstraint]=[]
        for (row,pair) in (target ? [(UInt64(12),("b","c"))] : [(UInt64(11),("a","b")),(UInt64(12),("b","c"))]) {
            var coefficients=[Double](repeating:0,count:p);coefficients[try entry(pair.0).positions.start]=1;coefficients[try entry(pair.1).positions.start] = -1
            rows.append(QuadraticConstraint(id:row,constant:0,linear:coefficients,hessian:[Double](repeating:0,count:p*p),timeLinear:0,timeQuadratic:0,mixedTime:[Double](repeating:0,count:p)))
        }
        let system=try QuadraticConstraintSystem(layout:q,rows:rows,minimumPosition:[Double](repeating:-10,count:p),maximumPosition:[Double](repeating:10,count:p),minimumTime:0,maximumTime:10)
        let tolerance=try LinearTolerance<Double>(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:1e-13)
        let nonlinear=try NonlinearPolicy<Double>(strategy:.lineSearch(contraction:0.5,sufficientDecrease:1e-4,minimumFraction:1e-7),
            capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),tolerance:tolerance,referenceScale:1,
            minimumDirectionNorm:0,derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-4,derivativeRelativeTolerance:1e-4,
            maximumFactorEntries:10000,estimateCondition:false,budget:work().budget)
        func policy(_ count:Int) throws -> ConstraintSolvePolicy {
            try ConstraintSolvePolicy(evaluation:ConstraintEvaluationPolicy(maximumCoordinates:32,maximumRows:8,expectedLayoutRevision:revision),
                diagonalMetric:[Double](repeating:1,count:count),energyScale:energy,rankPolicy:.allowRedundancy,rankRelativeTolerance:1e-10,
                originalResidualTolerance:1e-9,maximumCorrection:1,nonlinear:nonlinear,
                linearCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),linearTolerance:tolerance)
        }
        let solve=try MechanismSolvePolicy(dynamics:DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:tolerance,coordinateScales:v.scales,energyScale:energy,timeScale:1),constraints:policy(n),maximumCoordinates:32,maximumRows:8,
            originalTolerance:1e-8,isCancelled:cancelled)
        let projection=try NonlinearMechanismProjectionPolicy(position:policy(p),maximumIterations:12,maximumCorrection:0.1)
        var drive=[Double](repeating:0,count:n);drive[try entry("b").velocities.start] = effort
        if !target { drive[try entry("a").velocities.start]=4 }
        return try NonlinearMechanismEquation(identity:"sleep-topology-quadratic",sourceBoundModel:model,constraints:system,velocityLayout:v,drive:drive,
            policy:solve,projection:projection,admission:admission(),maximumIdentityBytes:65536,solver:solver)
    }
    static func integration(_ descriptor:ODEDescriptor) throws -> ExplicitIntegrationPolicy {
        try ExplicitIntegrationPolicy(method:.classicalRK4,initialStep:0.1,minimumStep:1e-8,maximumStep:0.1,safety:0.8,minimumFactor:0.1,maximumFactor:2,
            scales:descriptor.dimensions.map {try ODEErrorScale(dimension:$0,absoluteSI:1e-5,relative:0)},maximumContinuationBytes:262144,
            budget:IntegrationBudget(maximumCoordinates:64,maximumAttempts:100,maximumAcceptedSteps:100,maximumOuterArithmetic:1_000_000,
                supplier:NumericalBudget(scalarStorage:2_000_000,arithmeticOperations:100_000_000,iterations:100_000)))
    }
    static func historyPolicy() throws -> TopologyContinuationPolicy {
        try TopologyContinuationPolicy(maximumEvents:4,maximumBytes:262144,maximumMetadataBytes:262144,maximumWork:1_000_000)
    }
    static func rule() throws -> TopologyReleaseRule {
        try TopologyReleaseRule(id:1,joint:id(.joint,"a"),connector:id(.joint,"free-a"),parentAnchor:id(.frame,"free-a-parent"),
            childAnchor:id(.frame,"free-a-child"),subtreeRoot:id(.body,"a"),metric:.explicitRelease)
    }
    static func configuration(_ schemas:[RuntimeContributorSchema]) throws -> RuntimeConfiguration {
        try RuntimeConfiguration(continuation:RuntimeContinuationIdentity(build:"sleep-topology-test",backend:"reference-cpu",precision:"float64"),requiredContributors:schemas,
            capacity:RuntimeCapacity(maximumPhysicalScalars:256,maximumContributors:8,maximumContributorBytes:524288,maximumMetadataBytes:262144,
                maximumCheckpointBytes:1048576,maximumValidationWork:100_000_000,maximumValidationScratchBytes:16_000_000,maximumObservationLeases:2,
                maximumBatchStates:2,maximumTransactions:1000,maximumStepWorkUnits:100000,maximumWorkBetweenSafePoints:4),determinism:.sameBuildReplay,workload:"sleep-topology-real-release")
    }
    static func source(mass:Double = 2,energy:Double = 1) throws -> Source {
        let model=try model(mass:mass),equation=try equation(model,energy:energy)
        let owner=try CheckpointedMechanismSleep(identity:"sleep-topology-source",model:model,constraints:equation.constraints,drive:equation.drive,
            solvePolicy:equation.policy,admission:admission(),policy:MechanismSleepContinuationPolicy(thresholds:MechanismSleepPolicy(maximumCoordinates:32,
                kineticEnergyThreshold:1e-8,normalizedVelocityThreshold:1e-8),minimumRestDuration:0.15,maximumIdentityBytes:65536),integration:integration(equation.descriptor))
        let history=try TopologyHistoryContributor(model:model,catalog:TopologyEventCatalog(initialModel:model.stamp,initialTime:0,initialSequence:0,rules:[rule()],policy:historyPolicy()),policy:historyPolicy())
        let config=try configuration(owner.schemas+history.schemas),registry=try TopologyRuntimeContributors(providers:[owner,history],capacity:config.capacity)
        let inner=SleepTopologySourceCheckpointHandler(sleep:owner,additional:history,revisions:ReferenceModelRevisionUpdater())
        let handler=TopologyCheckpointHandler(history:history,contributors:registry,base:inner)
        let affine=try AffineMechanismEquation(identity:owner.descriptor.identity,model:model,constraints:owner.constraints,drive:equation.drive,
            policy:owner.solvePolicy,admission:owner.admission,maximumIdentityBytes:owner.policy.maximumIdentityBytes)
        let state=model.descriptor.initialState
        let session=try Session(model:model,configuration:config,initialState:state,contributors:[owner.initialRecord(physical:state),
            owner.continuation.initialRecord(physical:state,equations:affine),history.record],seed:42,checkpoints:handler)
        return Source(model:model,owner:owner,history:history,handler:handler,session:session)
    }
    static func enter(_ source:Source) throws -> (Int,Int) {
        let active=try source.owner.step(source.session).work.supplierArithmeticCharged
        _=try source.owner.step(source.session)
        let sleeping=try source.owner.step(source.session).work.supplierArithmeticCharged
        return (active,sleeping)
    }
    static func release(_ source:Source,accepted:RuntimeAcceptedState? = nil) throws -> SubtreeRelease {
        let rule=try rule(),t=try NumericalTolerance(absolute:1e-9,relative:1e-9)
        var work=try work(),dynamics=try self.work()
        return try ReferenceSubtreeReleaseBuilder().release(model:source.model,state:accepted?.physical ?? source.session.snapshot().physical,
            joint:rule.joint,connector:rule.connector,parentAnchor:rule.parentAnchor,childAnchor:rule.childAnchor,
            policy:SubtreeReleasePolicy(maximumBodies:8,maximumCoordinates:32,translation:t,rotation:t,linearVelocity:t,angularVelocity:t,
                kineticEnergy:t,linearMomentum:t,angularMomentum:t),admission:admission(),work:&work,dynamicsWork:&dynamics)
    }
    static func retained(_ equation:NonlinearMechanismEquation) throws -> QuadraticConstraintSystem {
        let c=equation.constraints
        return try QuadraticConstraintSystem(layout:c.layout,rows:c.rows.filter {$0.id != UInt64.max},minimumPosition:c.minimumPosition,
            maximumPosition:c.maximumPosition,minimumTime:c.minimumTime,maximumTime:c.maximumTime)
    }
    static func select(_ source:Source,accepted:RuntimeAcceptedState? = nil,energy:Double = 1) throws -> Selection {
        let accepted=accepted ?? source.session.snapshot(),release=try release(source,accepted:accepted),equations=try equation(release.target,target:true,energy:energy)
        var work=try work()
        let retiring:any MechanismSleepTopologyRetiring=source.owner
        let retirement=try retiring.prepareRetirement(source:accepted,sourceConfiguration:source.session.configuration,checkpoints:source.handler,
            release:release,retiredConstraintIDs:[11],targetConstraints:retained(equations),targetVelocityLayout:equations.velocityLayout,cancellation:nil,work:&work)
        let transition=try ReferenceNonlinearSubtreeAccelerationPreparer().prepare(release:release,equations:equations,work:&work)
        let history=try source.history.appending(source:accepted,target:transition,observation:.explicit(release),ruleID:1)
        let wake=try SleepTopologyWakeContributor(retirement:retirement,transition:transition,history:history,ruleID:1,policy:historyPolicy(),work:&work)
        let continuation=try IntegrationContinuationProvider(descriptor:equations.descriptor,policy:integration(equations.descriptor))
        let preparing:any SleepTopologyTransitionPreparing=ReferenceSleepTopologyTransitionPreparer()
        let prepared=try preparing.prepare(source:accepted,sourceConfiguration:source.session.configuration,retirement:retirement,
            transition:transition,history:source.history,observation:.explicit(release),ruleID:1,
            dispositions:[.appendHistory,.retireSleep,.initializeGlobalIntegration(retiredID:source.owner.continuation.schema.id)],
            targetConfiguration:configuration(history.schemas+wake.schemas+continuation.schemas),equations:equations,continuation:continuation,
            validationBudget:work.budget,cancellation:nil,work:&work)
        return Selection(retirement:retirement,transition:transition,equations:equations,continuation:continuation,history:history,wake:wake,prepared:prepared)
    }
    static func cold(_ selected:Selection) throws -> RuntimeSession<SleepTopologyCheckpointHandler> {
        let model=selected.transition.release.target,physical=try model.makeState(selected.transition.physical)
        let empty=try TopologyHistoryContributor(model:model,catalog:TopologyEventCatalog(initialModel:model.stamp,initialTime:physical.state.time,
            initialSequence:0,rules:selected.history.catalog.rules,policy:historyPolicy()),policy:historyPolicy())
        var work=try work()
        let boot=try SleepTopologyWakeContributor(bootstrapFor:selected.wake,physical:physical,work:&work)
        let normal=try TopologyRuntimeContributors(providers:[selected.history,selected.wake,selected.continuation],capacity:selected.prepared.configuration.capacity)
        let bootstrap=try TopologyRuntimeContributors(providers:[empty,boot,selected.continuation],capacity:selected.prepared.configuration.capacity)
        let base=try TopologyCheckpointHandler(history:selected.history,contributors:normal,bootstrap:empty,physical:physical,bootstrapContributors:bootstrap)
        let handler=try SleepTopologyCheckpointHandler(wake:selected.wake,history:selected.history,equations:selected.equations,
            continuation:selected.continuation,base:base,validationBudget:work.budget,bootstrapWake:boot,bootstrapHistory:empty,bootstrapPhysical:physical)
        return try RuntimeSession(model:model,configuration:selected.prepared.configuration,initialState:physical.state,
            contributors:[empty.record,boot.record,selected.continuation.initialRecord(physical:physical.state,equations:selected.equations)],seed:42,checkpoints:handler)
    }
}
