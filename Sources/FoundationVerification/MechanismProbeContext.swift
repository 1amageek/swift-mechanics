import MechanicsCore
import MechanicsModel
import MechanicsCompiler
import MechanicsJoints
import MechanicsNumerics
import MechanicsNonlinear
import MechanicsConstraints
import MechanicsTransmissions
import MechanicsDynamics
import MechanicsLoads
import MechanicsRuntime
import MechanicsIntegration
import MechanicsMechanisms

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
enum MechanismProbeContext {
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func work(storage:Int = 1_000_000,operations:Int = 20_000_000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:100000))
    }
    static func model(q:[Double] = [0,0],v:[Double] = [0,0]) throws -> CompiledMechanicalModel {
        let tolerance=try NumericalTolerance(absolute:1e-12,relative:1e-12),inertiaPolicy=try InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0)
        var bodies:[MechanicalBody]=[]
        for (index,key) in ["root","a","b"].enumerated() {
            let j=[1.0,2.0,4.0][index]
            let properties=try MassProperties3D(mass:1,centerOfMass:.zero,inertiaAtCenter:Matrix3(j,0,0,0,j,0,0,0,j),policy:inertiaPolicy)
            let record=try BodyRecord3D(id:id(.body,key),frame:id(.frame,key+"-frame"),mode:index == 0 ? .static : .dynamic,
                bodyToWorld:RigidTransform(rotation:UnitQuaternion(axis:.unitZ,angle:index == 0 ? 0 : q[index-1]),translation:.zero),representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:properties,
                    provenance:SourceProvenance(source:"mechanism-inertia",revision:1),quality:.exact))
            bodies.append(.spatial(record))
        }
        var joints:[MechanicalJoint]=[]
        for key in ["a","b"] {
            let record=try JointRecord(id:id(.joint,key),parentBody:id(.body,"root"),childBody:id(.body,key),
                parentAnchor:JointAnchor(frame:id(.frame,key+"-parent"),placement:.fixed(.identity)),
                childAnchor:JointAnchor(frame:id(.frame,key+"-child"),placement:.fixed(.identity)),manifold:JointManifold(.revolute(axis:.unitZ)))
            joints.append(MechanicalJoint(record:record,authority:.dynamicState))
        }
        let initial=try KinematicState(revision:1,time:0,q:q,v:v,acceleration:[0,0])
        let descriptor=try MechanicalDescriptor(identity:"real-gears",revision:1,bodies:bodies,joints:joints,root:id(.body,"root"),rootBase:.fixed,
            rootAuthority:.fixed,worldFrame:id(.frame,"world"),initialState:initial,representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:8,maximumVelocities:8,maximumJacobianScalars:1000),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-10,characteristicLengthMeters:1),inertiaPolicy:inertiaPolicy,
            translationTolerance:tolerance,rotationTolerance:tolerance,maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:1000,
            maximumDependencyEntries:1000,maximumExtensionRecords:8,maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }
    static func layout() throws -> ConstraintCoordinateLayout {
        try ConstraintCoordinateLayout(coordinateIDs:[10,20],dimensions:[.angle,.angle],scales:[2,3],timeScale:5,revision:1)
    }
    static func policy(cancelled:Bool = false) throws -> MechanismSolvePolicy {
        let tolerance=try LinearTolerance<Double>(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:1e-13)
        let nonlinear=try NonlinearPolicy<Double>(strategy:.lineSearch(contraction:0.5,sufficientDecrease:1e-4,minimumFraction:1e-7),
            capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),tolerance:tolerance,referenceScale:1,
            minimumDirectionNorm:0,derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-4,derivativeRelativeTolerance:1e-4,
            maximumFactorEntries:1000,estimateCondition:false,budget:work().budget)
        let constraints=try ConstraintSolvePolicy(evaluation:ConstraintEvaluationPolicy(maximumCoordinates:8,maximumRows:8,expectedLayoutRevision:1),
            diagonalMetric:[1,1],energyScale:7,rankPolicy:.allowRedundancy,rankRelativeTolerance:1e-10,originalResidualTolerance:1e-8,maximumCorrection:100,
            nonlinear:nonlinear,linearCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),linearTolerance:tolerance)
        return try MechanismSolvePolicy(dynamics:DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:tolerance,coordinateScales:[2,3],energyScale:7,timeScale:5),constraints:constraints,maximumCoordinates:8,maximumRows:8,
            originalTolerance:1e-8,isCancelled:{cancelled})
    }
    static func admission() throws -> DynamicsAdmission {
        DynamicsAdmission(capacity:try DynamicsCapacity(maximumBodies:8,maximumVelocities:8,maximumBodyWrenches:8,maximumGeneralizedContributions:8),
            angularVelocityTolerance:try NumericalTolerance(absolute:1e-10,relative:1e-10),linearVelocityTolerance:try NumericalTolerance(absolute:1e-10,relative:1e-10))
    }
    static func system(_ model:CompiledMechanicalModel) throws -> RigidDynamicsSystem {
        var inertias:[RigidBodyInertia]=[]
        for body in model.initialSnapshot.bodies {
            guard let raw=model.descriptor.bodies.first(where:{$0.id == body.body}),case .spatial(let source)=raw,let inertia=source.inertia else { throw MechanismError.invalidShape }
            inertias.append(try RigidBodyInertia(body:source.id,frame:source.frame,properties:inertia.properties))
        }
        var work=try work(),load=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0))
        return try RigidEquationKernel().assemble(RigidDynamicsInput(snapshot:model.initialSnapshot,velocity:model.descriptor.initialState.v,inertias:inertias,gravity:nil),
            admission:admission(),loadWork:&load,work:&work)
    }
    static func sample(rows:[Double] = [2,6],ids:[UInt64] = [1],bias:[Double] = [0]) throws -> VelocityConstraintSample {
        VelocityConstraintSample(layout:try layout(),rowIDs:ids,rows:rows,drift:[Double](repeating:0,count:ids.count),accelerationBias:bias,isIntegrable:true)
    }
    static func equations(lock:Bool = false) throws -> QuadraticConstraintSystem {
        let row=QuadraticConstraint(id:1,constant:0,linear:lock ? [2,-3] : [2,6],hessian:[0,0,0,0],timeLinear:0,timeQuadratic:0,mixedTime:[0,0])
        return try QuadraticConstraintSystem(layout:layout(),rows:[row],minimumPosition:[-100,-100],maximumPosition:[100,100],minimumTime:0,maximumTime:10)
    }
    static func equation(_ model:CompiledMechanicalModel,lock:Bool = false) throws -> AffineMechanismEquation {
        try AffineMechanismEquation(identity:lock ? "stationary-lock" : "real-gear",model:model,constraints:equations(lock:lock),drive:lock ? [0,0] : [6,0],
            policy:policy(),admission:admission(),maximumIdentityBytes:1024)
    }
    static func integrationPolicy(adaptive:Bool = false) throws -> ExplicitIntegrationPolicy {
        try ExplicitIntegrationPolicy(method:adaptive ? .heunEuler : .classicalRK4,initialStep:0.1,minimumStep:1e-8,maximumStep:0.1,safety:0.8,minimumFactor:0.1,maximumFactor:2,
            scales:[ODEErrorScale(dimension:.angle,absoluteSI:1e-5,relative:0),ODEErrorScale(dimension:.angle,absoluteSI:1e-5,relative:0),
                    ODEErrorScale(dimension:PhysicalDimension(time:-1,angle:1),absoluteSI:1e-5,relative:0),ODEErrorScale(dimension:PhysicalDimension(time:-1,angle:1),absoluteSI:1e-5,relative:0)],
            maximumContinuationBytes:2048,budget:IntegrationBudget(maximumCoordinates:4,maximumAttempts:1000,maximumAcceptedSteps:1000,maximumOuterArithmetic:1_000_000,
                supplier:NumericalBudget(scalarStorage:1_000_000,arithmeticOperations:100_000_000,iterations:100_000)))
    }
    typealias Session=RuntimeSession<ReferenceRuntimeCheckpointHandler<IntegrationContinuationProvider,ReferenceModelRevisionUpdater>>
    static func session(_ model:CompiledMechanicalModel,equation:AffineMechanismEquation,adaptive:Bool = false) throws -> (Session,IntegrationContinuationProvider) {
        let continuation=try IntegrationContinuationProvider(descriptor:equation.descriptor,policy:integrationPolicy(adaptive:adaptive))
        let configuration=try RuntimeConfiguration(continuation:RuntimeContinuationIdentity(build:"mechanisms-v1",backend:"reference-cpu",precision:"float64"),requiredContributors:continuation.schemas,
            capacity:RuntimeCapacity(maximumPhysicalScalars:64,maximumContributors:4,maximumContributorBytes:4096,maximumMetadataBytes:4096,maximumCheckpointBytes:8192,
                maximumValidationWork:8192,maximumValidationScratchBytes:8192,maximumObservationLeases:2,maximumBatchStates:2,maximumTransactions:10000,maximumStepWorkUnits:100000,maximumWorkBetweenSafePoints:4),
            determinism:.sameBuildReplay,workload:"real-gear")
        let handler=try ReferenceRuntimeCheckpointHandler(contributors:continuation,revisions:ReferenceModelRevisionUpdater())
        let session=try Session(model:model,configuration:configuration,initialState:model.descriptor.initialState,
            contributors:[continuation.initialRecord(physical:model.descriptor.initialState,equations:equation)],seed:42,checkpoints:handler)
        return (session,continuation)
    }
}
