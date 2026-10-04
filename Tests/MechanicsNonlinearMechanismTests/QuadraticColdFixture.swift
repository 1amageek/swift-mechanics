import SwiftMechanics

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct QuadraticColdFixture {
    let model:CompiledMechanicalModel
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    init(changedMass:Double = 2) throws {
        let t=try NumericalTolerance(absolute:1e-10,relative:1e-10),ip=try InertiaValidationPolicy(symmetry:t,physicalityRelative:0)
        var bodies:[MechanicalBody]=[];var joints:[MechanicalJoint]=[]
        for key in ["root","a","b","c"] {
            let mass=key == "c" ? changedMass : 2
            let p=try MassProperties3D(mass:mass,centerOfMass:.zero,inertiaAtCenter:Matrix3(1,0,0,0,1,0,0,0,1),policy:ip)
            bodies.append(.spatial(try BodyRecord3D(id:Self.id(.body,key),frame:Self.id(.frame,key+"-body"),mode:key == "root" ? .static : .dynamic,
                bodyToWorld:.identity,representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:p,
                    provenance:SourceProvenance(source:"quadratic-cold",revision:1),quality:.exact))))
            if key != "root" {
                let joint=try JointRecord(id:Self.id(.joint,key),parentBody:Self.id(.body,"root"),childBody:Self.id(.body,key),
                    parentAnchor:JointAnchor(frame:Self.id(.frame,key+"-parent"),placement:.fixed(.identity)),
                    childAnchor:JointAnchor(frame:Self.id(.frame,key+"-child"),placement:.fixed(.identity)),manifold:JointManifold(.prismatic(axis:.unitY)))
                joints.append(MechanicalJoint(record:joint,authority:.dynamicState))
            }
        }
        let initial=try KinematicState(revision:1,time:0,q:[0,0,0],v:[0,0,0],acceleration:[0,0,0])
        let d=try MechanicalDescriptor(identity:"quadratic-three-sliders",revision:1,bodies:bodies,joints:joints,root:Self.id(.body,"root"),rootBase:.fixed,
            rootAuthority:.fixed,worldFrame:Self.id(.frame,"world"),initialState:initial,representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:8,maximumVelocities:24,maximumJacobianScalars:20000),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:t,chartRankRelative:1e-10,characteristicLengthMeters:1),inertiaPolicy:ip,
            translationTolerance:t,rotationTolerance:t,maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:10000,
            maximumDependencyEntries:10000,maximumExtensionRecords:8,maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        model=try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(d,policy:policy)
    }
    static func work() throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:2_000_000,arithmeticOperations:100_000_000,iterations:1000))
    }
    static func admission() throws -> DynamicsAdmission {
        DynamicsAdmission(capacity:try DynamicsCapacity(maximumBodies:8,maximumVelocities:24,maximumBodyWrenches:0,maximumGeneralizedContributions:0),
            angularVelocityTolerance:try NumericalTolerance(absolute:1e-10,relative:1e-10),linearVelocityTolerance:try NumericalTolerance(absolute:1e-10,relative:1e-10))
    }
    func release() throws -> SubtreeRelease {
        let t=try NumericalTolerance(absolute:1e-9,relative:1e-9)
        let policy=try SubtreeReleasePolicy(maximumBodies:8,maximumCoordinates:24,translation:t,rotation:t,linearVelocity:t,angularVelocity:t,
            kineticEnergy:t,linearMomentum:t,angularMomentum:t)
        var work=try Self.work(),dynamics=try Self.work()
        return try ReferenceSubtreeReleaseBuilder().release(model:model,state:model.makeState(model.descriptor.initialState),joint:Self.id(.joint,"a"),
            connector:Self.id(.joint,"free-a"),parentAnchor:Self.id(.frame,"free-a-parent"),childAnchor:Self.id(.frame,"free-a-child"),
            policy:policy,admission:Self.admission(),work:&work,dynamicsWork:&dynamics)
    }
    static func equation(_ model:CompiledMechanicalModel,target:Bool = false,strict:Bool = true,
                         evaluator:any ConstraintEvaluating = QuadraticConstraintEvaluator(),solver:any ConstrainedMechanismSolving = MassWeightedMechanismSolver(),
                         isCancelled:@escaping @Sendable () -> Bool = {false}) throws -> NonlinearMechanismEquation {
        let p=model.tree.layout.positionCount,n=model.tree.layout.velocityCount,revision=model.stamp.revision
        var qDimensions=[PhysicalDimension](repeating:.length,count:p),vDimensions=[PhysicalDimension](repeating:.length,count:n)
        for entry in model.tree.layout.joints where entry.positions.count == 7 {
            for i in (entry.positions.start+3)..<entry.positions.end { qDimensions[i] = .dimensionless }
            for i in (entry.velocities.start+3)..<entry.velocities.end { vDimensions[i] = .angle }
        }
        let q=try ConstraintCoordinateLayout(coordinateIDs:(0..<p).map {UInt64(100+$0)},dimensions:qDimensions,scales:[Double](repeating:1,count:p),timeScale:1,revision:revision)
        let v=try ConstraintCoordinateLayout(coordinateIDs:(0..<n).map {UInt64(200+$0)},dimensions:vDimensions,scales:[Double](repeating:1,count:n),timeScale:1,revision:revision)
        func entry(_ key:String) throws -> JointCoordinateLayout {
            guard let result=model.tree.layout.joints.first(where:{$0.joint.key == key}) else { throw RuntimeFailure(.invalidInput,message:"Actual slider range absent.") };return result
        }
        var rows:[QuadraticConstraint]=[]
        for (row,pair) in (target ? [(UInt64(2),("b","c"))] : [(UInt64(1),("a","b")),(UInt64(2),("b","c"))]) {
            var linear=[Double](repeating:0,count:p);linear[try entry(pair.0).positions.start]=1;linear[try entry(pair.1).positions.start] = -1
            rows.append(QuadraticConstraint(id:row,constant:0,linear:linear,hessian:[Double](repeating:0,count:p*p),timeLinear:0,timeQuadratic:0,mixedTime:[Double](repeating:0,count:p)))
        }
        let system=try QuadraticConstraintSystem(layout:q,rows:rows,minimumPosition:[Double](repeating:-10,count:p),maximumPosition:[Double](repeating:10,count:p),minimumTime:0,maximumTime:10)
        let tolerance=try LinearTolerance<Double>(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:1e-13)
        let original=try NonlinearMechanismFixtures.policy().constraints
        func constraintPolicy(_ count:Int) throws -> ConstraintSolvePolicy {
            try ConstraintSolvePolicy(evaluation:ConstraintEvaluationPolicy(maximumCoordinates:24,maximumRows:16,expectedLayoutRevision:revision),
                diagonalMetric:[Double](repeating:1,count:count),energyScale:1,rankPolicy:.allowRedundancy,rankRelativeTolerance:1e-10,
                originalResidualTolerance:1e-9,maximumCorrection:1,nonlinear:original.nonlinear,
                linearCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),linearTolerance:tolerance)
        }
        let policy=try MechanismSolvePolicy(dynamics:DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:tolerance,coordinateScales:v.scales,energyScale:1,timeScale:1),constraints:constraintPolicy(n),maximumCoordinates:24,maximumRows:16,
            originalTolerance:1e-8,isCancelled:isCancelled)
        let projection=try NonlinearMechanismProjectionPolicy(position:constraintPolicy(p),maximumIterations:12,maximumCorrection:0.1)
        var drive=[Double](repeating:0,count:n);drive[try entry("b").velocities.start] = -4
        if !target { drive[try entry("a").velocities.start]=4 }
        if strict {
            return try NonlinearMechanismEquation(identity:"quadratic-cold",sourceBoundModel:model,constraints:system,velocityLayout:v,drive:drive,
                policy:policy,projection:projection,admission:admission(),maximumIdentityBytes:65536,evaluator:evaluator,solver:solver)
        }
        return try NonlinearMechanismEquation(identity:"quadratic-cold",model:model,constraints:system,velocityLayout:v,drive:drive,
            policy:policy,projection:projection,admission:admission(),maximumIdentityBytes:65536,evaluator:evaluator,solver:solver)
    }
    typealias Session=RuntimeSession<NonlinearMechanismCheckpointHandler>
    static func session(_ equation:NonlinearMechanismEquation,initial:KinematicState? = nil) throws -> (Session,IntegrationContinuationProvider) {
        let (temporary,continuation)=try NonlinearMechanismFixtures.session(equation)
        let configuration=temporary.configuration;_ = temporary.shutdown()
        let base=ReferenceRuntimeCheckpointHandler(contributors:continuation,revisions:ReferenceModelRevisionUpdater())
        let handler=try NonlinearMechanismCheckpointHandler(equations:equation,continuation:continuation,base:base,validationBudget:work().budget)
        let state=initial ?? equation.model.descriptor.initialState
        return (try Session(model:equation.model,configuration:configuration,initialState:state,
            contributors:[continuation.initialRecord(physical:state,equations:equation)],seed:42,checkpoints:handler),continuation)
    }
}
