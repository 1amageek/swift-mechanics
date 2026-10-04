import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal enum NonlinearMechanismFixtures {
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func work(storage:Int = 1_000_000,operations:Int = 20_000_000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:100000))
    }
    static func model(q:[Double] = [1,0],v:[Double] = [0,1],spherical:Bool = false) throws -> CompiledMechanicalModel {
        let tolerance=try NumericalTolerance(absolute:1e-10,relative:1e-10),inertiaPolicy=try InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0)
        var bodies:[MechanicalBody]=[]
        for key in ["root","mass"] {
            let properties=try MassProperties3D(mass:1,centerOfMass:.zero,inertiaAtCenter:Matrix3(1,0,0,0,1,0,0,0,1),policy:inertiaPolicy)
            let pose:RigidTransform
            if key == "root" { pose = .identity }
            else if spherical { pose=RigidTransform(rotation:try UnitQuaternion(w:q[0],x:q[1],y:q[2],z:q[3]),translation:.zero) }
            else { pose=RigidTransform(rotation:.identity,translation:try Vector3(q[0],q[1],0)) }
            let record=try BodyRecord3D(id:id(.body,key),frame:id(.frame,key+"-frame"),mode:key == "root" ? .static : .dynamic,
                bodyToWorld:pose,representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:properties,
                    provenance:SourceProvenance(source:"nonlinear-inertia",revision:1),quality:.exact))
            bodies.append(.spatial(record))
        }
        let specification:JointSpecification=spherical ? .spherical : .custom(orderedAxes:[try JointAxis(kind:.prismatic,direction:.unitX),try JointAxis(kind:.prismatic,direction:.unitY)])
        let record=try JointRecord(id:id(.joint,"mass"),parentBody:id(.body,"root"),childBody:id(.body,"mass"),
                parentAnchor:JointAnchor(frame:id(.frame,"mass-parent"),placement:.fixed(.identity)),
                childAnchor:JointAnchor(frame:id(.frame,"mass-child"),placement:.fixed(.identity)),manifold:JointManifold(specification))
        let initial=try KinematicState(revision:1,time:0,q:q,v:v,acceleration:[Double](repeating:0,count:v.count))
        let descriptor=try MechanicalDescriptor(identity:spherical ? "quaternion-spin" : "cartesian-pendulum",revision:1,bodies:bodies,
            joints:[MechanicalJoint(record:record,authority:.dynamicState)],root:id(.body,"root"),rootBase:.fixed,
            rootAuthority:.fixed,worldFrame:id(.frame,"world"),initialState:initial,representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:8,maximumVelocities:8,maximumJacobianScalars:1000),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-10,characteristicLengthMeters:1),inertiaPolicy:inertiaPolicy,
            translationTolerance:tolerance,rotationTolerance:tolerance,maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:1000,
            maximumDependencyEntries:1000,maximumExtensionRecords:8,maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }
    static func layout() throws -> ConstraintCoordinateLayout {
        try ConstraintCoordinateLayout(coordinateIDs:[10,20],dimensions:[.length,.length],scales:[2,3],timeScale:5,revision:1)
    }
    static func policy(cancelled:Bool = false,scales:[Double] = [2,3],gramLU:Bool = false) throws -> MechanismSolvePolicy {
        let tolerance=try LinearTolerance<Double>(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:1e-13)
        let nonlinear=try NonlinearPolicy<Double>(strategy:.lineSearch(contraction:0.5,sufficientDecrease:1e-4,minimumFraction:1e-7),
            capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),tolerance:tolerance,referenceScale:1,
            minimumDirectionNorm:0,derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-4,derivativeRelativeTolerance:1e-4,
            maximumFactorEntries:1000,estimateCondition:false,budget:work().budget)
        let constraints=try ConstraintSolvePolicy(evaluation:ConstraintEvaluationPolicy(maximumCoordinates:8,maximumRows:8,expectedLayoutRevision:1),
            diagonalMetric:[Double](repeating:1,count:scales.count),energyScale:7,rankPolicy:.allowRedundancy,rankRelativeTolerance:1e-10,originalResidualTolerance:1e-8,maximumCorrection:100,
            nonlinear:nonlinear,linearCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:gramLU ? .partialPivotLU : .cholesky),linearTolerance:tolerance)
        return try MechanismSolvePolicy(dynamics:DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:tolerance,coordinateScales:scales,energyScale:7,timeScale:5),constraints:constraints,maximumCoordinates:8,maximumRows:8,
            originalTolerance:1e-8,isCancelled:{cancelled})
    }
    static func admission() throws -> DynamicsAdmission {
        DynamicsAdmission(capacity:try DynamicsCapacity(maximumBodies:8,maximumVelocities:8,maximumBodyWrenches:8,maximumGeneralizedContributions:8),
            angularVelocityTolerance:try NumericalTolerance(absolute:1e-10,relative:1e-10),linearVelocityTolerance:try NumericalTolerance(absolute:1e-10,relative:1e-10))
    }
    static func projection(_ layout:ConstraintCoordinateLayout) throws -> NonlinearMechanismProjectionPolicy {
        let p=try policy(scales:layout.scales).constraints
        let cp=try ConstraintSolvePolicy(evaluation:p.evaluation,diagonalMetric:p.diagonalMetric,energyScale:p.energyScale,rankPolicy:p.rankPolicy,
            rankRelativeTolerance:p.rankRelativeTolerance,originalResidualTolerance:1e-11,maximumCorrection:1,nonlinear:p.nonlinear,linearCapability:p.linearCapability,linearTolerance:p.linearTolerance)
        return try NonlinearMechanismProjectionPolicy(position:cp,maximumIterations:12,maximumCorrection:0.5)
    }
    static func equation(_ model:CompiledMechanicalModel,drive:[Double] = [0,0],redundant:Bool = false,
                         evaluator:any ConstraintEvaluating = QuadraticConstraintEvaluator(),kernel:any RigidEquationComputing = RigidEquationKernel()) throws -> NonlinearMechanismEquation {
        let layout=try layout()
        let row=QuadraticConstraint(id:1,constant:-1,linear:[0,0],hessian:[8,0,0,18],timeLinear:0,timeQuadratic:0,mixedTime:[0,0])
        let rows=redundant ? [row,QuadraticConstraint(id:2,constant:-2,linear:[0,0],hessian:[16,0,0,36],timeLinear:0,timeQuadratic:0,mixedTime:[0,0])] : [row]
        let equations=try QuadraticConstraintSystem(layout:layout,rows:rows,minimumPosition:[-10,-10],maximumPosition:[10,10],minimumTime:0,maximumTime:100)
        return try NonlinearMechanismEquation(identity:"nonlinear-circle",model:model,constraints:equations,velocityLayout:layout,drive:drive,
            policy:policy(),projection:projection(layout),admission:admission(),maximumIdentityBytes:8192,kernel:kernel,evaluator:evaluator)
    }
    static func quaternionEquation(_ model:CompiledMechanicalModel,solver:any ConstrainedMechanismSolving = MassWeightedMechanismSolver()) throws -> NonlinearMechanismEquation {
        let q=try ConstraintCoordinateLayout(coordinateIDs:[1,2,3,4],dimensions:[.dimensionless,.dimensionless,.dimensionless,.dimensionless],scales:[1,1,1,1],timeScale:5,revision:1)
        let v=try ConstraintCoordinateLayout(coordinateIDs:[11,12,13],dimensions:[.angle,.angle,.angle],scales:[2,3,4],timeScale:5,revision:1)
        var rows:[QuadraticConstraint]=[]
        for index in [1,2] { var linear=[Double](repeating:0,count:4);linear[index]=1
            rows.append(QuadraticConstraint(id:UInt64(index),constant:0,linear:linear,hessian:[Double](repeating:0,count:16),timeLinear:0,timeQuadratic:0,mixedTime:[0,0,0,0])) }
        let equations=try QuadraticConstraintSystem(layout:q,rows:rows,minimumPosition:[-2,-2,-2,-2],maximumPosition:[2,2,2,2],minimumTime:0,maximumTime:100)
        return try NonlinearMechanismEquation(identity:"nonlinear-quaternion",model:model,constraints:equations,velocityLayout:v,drive:[0,0,0],
            policy:policy(scales:v.scales,gramLU:true),projection:projection(q),admission:admission(),maximumIdentityBytes:8192,solver:solver)
    }
    typealias Session=RuntimeSession<ReferenceRuntimeCheckpointHandler<IntegrationContinuationProvider,ReferenceModelRevisionUpdater>>
    static func session(_ equation:any ProjectedMechanismEquations,step:Double = 0.01,adaptive:Bool = false) throws -> (Session,IntegrationContinuationProvider) {
        let scales=try equation.descriptor.dimensions.map { try ODEErrorScale(dimension:$0,absoluteSI:1e-6,relative:0) }
        let ip=try ExplicitIntegrationPolicy(method:adaptive ? .heunEuler : .classicalRK4,initialStep:step,minimumStep:1e-8,maximumStep:step,safety:0.8,minimumFactor:0.1,maximumFactor:2,
            scales:scales,maximumContinuationBytes:65536,budget:IntegrationBudget(maximumCoordinates:max(16,equation.descriptor.dimensions.count),maximumAttempts:100000,maximumAcceptedSteps:100000,maximumOuterArithmetic:100_000_000,
                supplier:NumericalBudget(scalarStorage:1_000_000,arithmeticOperations:2_000_000_000,iterations:1_000_000)))
        let continuation=try IntegrationContinuationProvider(descriptor:equation.descriptor,policy:ip)
        let configuration=try RuntimeConfiguration(continuation:RuntimeContinuationIdentity(build:"nonlinear-v1",backend:"reference-cpu",precision:"float64"),requiredContributors:continuation.schemas,
            capacity:RuntimeCapacity(maximumPhysicalScalars:64,maximumContributors:4,maximumContributorBytes:131072,maximumMetadataBytes:131072,maximumCheckpointBytes:262144,
                maximumValidationWork:262144,maximumValidationScratchBytes:262144,maximumObservationLeases:2,maximumBatchStates:2,maximumTransactions:100000,maximumStepWorkUnits:1000000,maximumWorkBetweenSafePoints:4),
            determinism:.sameBuildReplay,workload:"nonlinear-mechanism")
        let handler=ReferenceRuntimeCheckpointHandler(contributors:continuation,revisions:ReferenceModelRevisionUpdater())
        let session=try Session(model:equation.model,configuration:configuration,initialState:equation.model.descriptor.initialState,
            contributors:[continuation.initialRecord(physical:equation.model.descriptor.initialState,equations:equation)],seed:42,checkpoints:handler)
        return (session,continuation)
    }
}
