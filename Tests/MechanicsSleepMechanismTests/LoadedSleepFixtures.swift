import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal enum LoadedSleepFixtures {
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func work() throws -> NumericalWork { try SleepFixtures.work() }
    static func model(q:[Double] = [-1,-1],v:[Double] = [0,0],mass:Double = 2) throws -> CompiledMechanicalModel {
        let tolerance=try NumericalTolerance(absolute:1e-12,relative:1e-12),inertiaPolicy=try InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0)
        var bodies:[MechanicalBody]=[]
        for (index,key) in ["root","a","b"].enumerated() {
            let j=[1.0,2.0,4.0][index]
            let properties=try MassProperties3D(mass:index == 0 ? 1 : mass,centerOfMass:.zero,inertiaAtCenter:Matrix3(j,0,0,0,j,0,0,0,j),policy:inertiaPolicy)
            let record=try BodyRecord3D(id:id(.body,key),frame:id(.frame,key+"-frame"),mode:index == 0 ? .static : .dynamic,
                bodyToWorld:RigidTransform(rotation:.identity,translation:index == 0 ? .zero : Vector3(0,q[index-1],0)),representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:properties,
                    provenance:SourceProvenance(source:"mechanism-inertia",revision:1),quality:.exact))
            bodies.append(.spatial(record))
        }
        var joints:[MechanicalJoint]=[]
        for key in ["a","b"] {
            let record=try JointRecord(id:id(.joint,key),parentBody:id(.body,"root"),childBody:id(.body,key),
                parentAnchor:JointAnchor(frame:id(.frame,key+"-parent"),placement:.fixed(.identity)),
                childAnchor:JointAnchor(frame:id(.frame,key+"-child"),placement:.fixed(.identity)),manifold:JointManifold(.prismatic(axis:.unitY)))
            joints.append(MechanicalJoint(record:record,authority:.dynamicState))
        }
        let initial=try KinematicState(revision:1,time:0,q:q,v:v,acceleration:[0,0])
        let descriptor=try MechanicalDescriptor(identity:"loaded-prismatic-test",revision:1,bodies:[bodies[2],bodies[0],bodies[1]],joints:joints,root:id(.body,"root"),rootBase:.fixed,
            rootAuthority:.fixed,worldFrame:id(.frame,"world"),initialState:initial,representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:8,maximumVelocities:8,maximumJacobianScalars:1000),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-10,characteristicLengthMeters:1),inertiaPolicy:inertiaPolicy,
            translationTolerance:tolerance,rotationTolerance:tolerance,maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:1000,
            maximumDependencyEntries:1000,maximumExtensionRecords:8,maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }
    static func layout() throws -> ConstraintCoordinateLayout {
        try ConstraintCoordinateLayout(coordinateIDs:[10,20],dimensions:[.length,.length],scales:[1,1],timeScale:1,revision:1)
    }
    static func policy(cancelled:Bool = false,energyScale:Double = 1) throws -> MechanismSolvePolicy {
        let tolerance=try LinearTolerance<Double>(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:1e-13)
        let nonlinear=try NonlinearPolicy<Double>(strategy:.lineSearch(contraction:0.5,sufficientDecrease:1e-4,minimumFraction:1e-7),
            capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),tolerance:tolerance,referenceScale:1,
            minimumDirectionNorm:0,derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-4,derivativeRelativeTolerance:1e-4,
            maximumFactorEntries:1000,estimateCondition:false,budget:work().budget)
        let constraints=try ConstraintSolvePolicy(evaluation:ConstraintEvaluationPolicy(maximumCoordinates:8,maximumRows:8,expectedLayoutRevision:1),
            diagonalMetric:[1,1],energyScale:energyScale,rankPolicy:.allowRedundancy,rankRelativeTolerance:1e-10,originalResidualTolerance:1e-8,maximumCorrection:100,
            nonlinear:nonlinear,linearCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),linearTolerance:tolerance)
        return try MechanismSolvePolicy(dynamics:DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:tolerance,coordinateScales:[1,1],energyScale:energyScale,timeScale:1),constraints:constraints,maximumCoordinates:8,maximumRows:8,
            originalTolerance:1e-8,isCancelled:{cancelled})
    }
    static func equations() throws -> QuadraticConstraintSystem {
        try QuadraticConstraintSystem(layout:layout(),rows:[QuadraticConstraint(id:1,constant:0,linear:[1,-1],hessian:[0,0,0,0],timeLinear:0,timeQuadratic:0,mixedTime:[0,0])],minimumPosition:[-100,-100],maximumPosition:[100,100],minimumTime:0,maximumTime:10)
    }
    static func catalog(_ model:CompiledMechanicalModel,stiffness:Double = 20,zeroLoads:Bool = false) throws -> StationaryLoadCatalog {
        let law=try PolynomialSpringDamper(coordinateKind:.translation,restCoordinate:0,quadraticStiffness:zeroLoads ? 0 : stiffness,linearDamping:0,maximumDisplacement:100,maximumRate:100)
        let terms=[StationaryScalarLoad(id:101,coordinateID:10,law:law),StationaryScalarLoad(id:102,coordinateID:20,law:law)]
        let programs=try [-10.0,-8.0].enumerated().map { index,y in StationaryLoadProgram(id:UInt64(index+1),revision:1,gravity:try AffineGravity(frame:model.tree.worldFrame,accelerationAtOrigin:Vector3(0,zeroLoads ? 0 : y,0)),terms:terms) }
        return try StationaryLoadCatalog(model:model,layout:layout(),programs:programs,capacity:StationaryLoadCapacity(maximumPrograms:4,maximumTermsPerProgram:4,maximumCoordinates:8,maximumMetadataBytes:16000))
    }
    static func integration() throws -> ExplicitIntegrationPolicy {
        try ExplicitIntegrationPolicy(method:.classicalRK4,initialStep:0.1,minimumStep:1e-8,maximumStep:0.1,safety:0.8,minimumFactor:0.1,maximumFactor:2,
            scales:[ODEErrorScale(dimension:.length,absoluteSI:1e-5,relative:0),ODEErrorScale(dimension:.length,absoluteSI:1e-5,relative:0),ODEErrorScale(dimension:.velocity,absoluteSI:1e-5,relative:0),ODEErrorScale(dimension:.velocity,absoluteSI:1e-5,relative:0)],
            maximumContinuationBytes:40000,budget:IntegrationBudget(maximumCoordinates:4,maximumAttempts:100,maximumAcceptedSteps:100,maximumOuterArithmetic:1_000_000,supplier:NumericalBudget(scalarStorage:1_000_000,arithmeticOperations:100_000_000,iterations:100_000)))
    }
    static func owner(_ model:CompiledMechanicalModel,dwell:Double = 0.15,energyScale:Double = 1,stiffness:Double = 20,zeroLoads:Bool = false) throws -> LoadedCheckpointedMechanismSleep {
        try LoadedCheckpointedMechanismSleep(identity:"loaded-prismatic-continuation",model:model,constraints:equations(),drive:[0,0],solvePolicy:policy(energyScale:energyScale),admission:SleepFixtures.admission(),policy:MechanismSleepContinuationPolicy(thresholds:MechanismSleepPolicy(maximumCoordinates:8,kineticEnergyThreshold:1e-8,normalizedVelocityThreshold:1e-8),minimumRestDuration:dwell,maximumIdentityBytes:16000),integration:integration(),catalog:catalog(model,stiffness:stiffness,zeroLoads:zeroLoads),initialSelection:StationaryLoadSelection(programID:1,revision:1,generation:0))
    }
    typealias Session=RuntimeSession<LoadedSleepRuntimeCheckpointHandler<ReferenceModelRevisionUpdater>>
    static func configuration(_ owner:LoadedCheckpointedMechanismSleep,validationWork:Int = 20_000_000) throws -> RuntimeConfiguration {
        try RuntimeConfiguration(continuation:RuntimeContinuationIdentity(build:"loaded-sleep-test",backend:"reference-cpu",precision:"float64"),requiredContributors:owner.schemas,
            capacity:RuntimeCapacity(maximumPhysicalScalars:64,maximumContributors:4,maximumContributorBytes:100000,maximumMetadataBytes:20000,maximumCheckpointBytes:200000,maximumValidationWork:validationWork,maximumValidationScratchBytes:8_000_000,maximumObservationLeases:2,maximumBatchStates:2,maximumTransactions:10000,maximumStepWorkUnits:100000,maximumWorkBetweenSafePoints:4),determinism:.sameBuildReplay,workload:"loaded-sleep")
    }
    static func session(_ model:CompiledMechanicalModel,owner:LoadedCheckpointedMechanismSleep,physical:KinematicState? = nil) throws -> Session {
        let state=physical ?? model.descriptor.initialState
        return try Session(model:model,configuration:configuration(owner),initialState:state,contributors:[owner.initialRecord(physical:state),owner.initialIntegrationRecord(physical:state)],seed:42,checkpoints:LoadedSleepRuntimeCheckpointHandler(sleep:owner,revisions:ReferenceModelRevisionUpdater()))
    }
    static func budget(work:Int = 10000,scalars:Int = 2,cancelled:Bool = false) throws -> LoadBudget { try LoadBudget(maximumWork:work,maximumScalars:scalars,isCancelled:{cancelled}) }
    static func history(_ owner:LoadedCheckpointedMechanismSleep,_ accepted:RuntimeAcceptedState) throws -> LoadedMechanismSleepHistory {
        guard let record=accepted.checkpoint.contributors.first(where:{$0.id == owner.schema.id}) else { throw RuntimeFailure(.missingContributor,message:"Loaded test history missing.") };return try owner.history(record)
    }
}
