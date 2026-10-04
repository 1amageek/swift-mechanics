import SwiftMechanics

internal enum ObservationFixtures {
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func work() throws -> NumericalWork { NumericalWork(budget:try NumericalBudget(scalarStorage:100000,arithmeticOperations:1000000,iterations:10000)) }
    static func policy(cancelled:Bool=false) throws -> ObservationPolicy {
        try ObservationPolicy(maximumBodies:4,maximumCoordinates:16,maximumReactionRows:16,maximumMetadataBytes:512,isCancelled:{cancelled})
    }
    static func model(kind:JointKind = .revolute,q:[Double]=[0],v:[Double]=[0],a:[Double]=[0],com:Vector3 = .zero,
                      identity:String="observed-model",revision:UInt64=1) throws -> CompiledMechanicalModel {
        let tolerance=try NumericalTolerance(absolute:1e-12,relative:1e-12)
        let validation=try InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0)
        let manifold:JointManifold,pose:RigidTransform
        switch kind {
        case .revolute: manifold=try JointManifold(.revolute(axis:.unitZ));pose=try RigidTransform(rotation:UnitQuaternion(axis:.unitZ,angle:q[0]),translation:.zero)
        case .prismatic: manifold=try JointManifold(.prismatic(axis:.unitY));pose=try RigidTransform(rotation:.identity,translation:Vector3(0,q[0],0))
        case .spherical: manifold=try JointManifold(.spherical);pose=try RigidTransform(rotation:UnitQuaternion(w:q[0],x:q[1],y:q[2],z:q[3]),translation:.zero)
        case .sixDOF: manifold=try JointManifold(.sixDOF);pose=try RigidTransform(rotation:UnitQuaternion(w:q[3],x:q[4],y:q[5],z:q[6]),translation:Vector3(q[0],q[1],q[2]))
        default:throw ObservationError.unsupportedChart
        }
        var bodies:[MechanicalBody]=[]
        for name in ["root","body"] {
            let mass:Double = name == "root" ? 1 : 2
            let properties=try MassProperties3D(mass:mass,centerOfMass:name == "root" ? .zero : com,inertiaAtCenter:Matrix3(mass,0,0,0,mass,0,0,0,mass),policy:validation)
            bodies.append(.spatial(try BodyRecord3D(id:id(.body,name),frame:id(.frame,name+"-frame"),mode:name == "root" ? .static : .dynamic,
                bodyToWorld:name == "root" ? .identity : pose,representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:properties,
                provenance:SourceProvenance(source:"observation-mass",revision:1),quality:.exact))))
        }
        let joint=try JointRecord(id:id(.joint,"joint"),parentBody:id(.body,"root"),childBody:id(.body,"body"),
            parentAnchor:JointAnchor(frame:id(.frame,"parent-anchor"),placement:.fixed(.identity)),
            childAnchor:JointAnchor(frame:id(.frame,"child-anchor"),placement:.fixed(.identity)),manifold:manifold)
        let state=try KinematicState(revision:revision,time:2,q:q,v:v,acceleration:a)
        let descriptor=try MechanicalDescriptor(identity:identity,revision:revision,bodies:bodies,joints:[MechanicalJoint(record:joint,authority:.dynamicState)],
            root:id(.body,"root"),rootBase:.fixed,rootAuthority:.fixed,worldFrame:id(.frame,"world"),initialState:state,
            representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:4,maximumVelocities:16,maximumJacobianScalars:1000),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-10,characteristicLengthMeters:1),inertiaPolicy:validation,
            translationTolerance:tolerance,rotationTolerance:tolerance,maximumRecords:100,maximumIdentifierBytes:1024,maximumSparsityEntries:1000,
            maximumDependencyEntries:1000,maximumExtensionRecords:8,maximumDiagnostics:8,extensionBudget:work().budget,target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }
    static func source(_ model:CompiledMechanicalModel) throws -> ObservationSource {
        var work=try work()
        return try ReferenceObservationSourcePreparer().prepare(model:model,state:model.makeState(model.descriptor.initialState),policy:policy(),work:&work)
    }
    static func mount(offset:Vector3 = .zero,angle:Double=0) throws -> ObservationMount {
        try ObservationMount(sensor:id(.sensor,"sensor"),body:id(.body,"body"),sensorFrame:id(.frame,"sensor-frame"),
            sensorToBody:RigidTransform(rotation:UnitQuaternion(axis:.unitZ,angle:angle),translation:offset))
    }
    static func gravity(_ source:ObservationSource,value:Vector3 = Vector3.zero) throws -> ObservationGravity {
        try ObservationGravity(model:source.model.stamp,timeSeconds:source.state.state.time,
            field:AffineGravity(frame:source.snapshot.tree.worldFrame,accelerationAtOrigin:value))
    }
    static func supported(_ model:CompiledMechanicalModel,impulse:Bool=false) throws -> ConstrainedMotion {
        let source=model.initialSnapshot
        var inertias:[RigidBodyInertia]=[]
        for body in source.bodies {
            guard let raw=model.descriptor.bodies.first(where:{$0.id == body.body}),case .spatial(let spatial)=raw,let inertia=spatial.inertia else { throw ObservationError.invalidInput }
            inertias.append(try RigidBodyInertia(body:body.body,frame:body.bodyFrame,properties:inertia.properties))
        }
        let input=try RigidDynamicsInput(snapshot:source,velocity:model.descriptor.initialState.v,inertias:inertias,
            gravity:AffineGravity(frame:source.tree.worldFrame,accelerationAtOrigin:Vector3(0,-10,0)))
        let admission=try DynamicsAdmission(capacity:try DynamicsCapacity(maximumBodies:4,maximumVelocities:4,maximumBodyWrenches:4,maximumGeneralizedContributions:4),
            angularVelocityTolerance:NumericalTolerance(absolute:1e-10,relative:1e-10),linearVelocityTolerance:NumericalTolerance(absolute:1e-10,relative:1e-10))
        var outer=try work(),dyn=try work(),rank=try work(),linear=try work(),load=LoadWork(budget:try LoadBudget(maximumWork:100,maximumScalars:100))
        let system=try RigidEquationKernel().assemble(input,admission:admission,loadWork:&load,work:&dyn)
        let layout=try ConstraintCoordinateLayout(coordinateIDs:[1],dimensions:[.length],scales:[1],timeScale:1,revision:model.stamp.revision)
        let sample=VelocityConstraintSample(layout:layout,rowIDs:[1],rows:[1],drift:[0],accelerationBias:[0],isIntegrable:true)
        let capability=LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky)
        let tolerance=try LinearTolerance<Double>(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:1e-12)
        let nonlinear=try NonlinearPolicy<Double>(strategy:.lineSearch(contraction:0.5,sufficientDecrease:1e-4,minimumFraction:1e-7),capability:capability,tolerance:tolerance,
            referenceScale:1,minimumDirectionNorm:0,derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-4,derivativeRelativeTolerance:1e-4,
            maximumFactorEntries:1000,estimateCondition:false,budget:work().budget)
        let constraints=try ConstraintSolvePolicy(evaluation:ConstraintEvaluationPolicy(maximumCoordinates:4,maximumRows:4,expectedLayoutRevision:model.stamp.revision),diagonalMetric:[1],energyScale:1,
            rankPolicy:.allowRedundancy,rankRelativeTolerance:1e-10,originalResidualTolerance:1e-8,maximumCorrection:100,nonlinear:nonlinear,linearCapability:capability,linearTolerance:tolerance)
        let policy=try MechanismSolvePolicy(dynamics:DynamicsSolvePolicy(capability:capability,linearTolerance:tolerance,coordinateScales:[1],energyScale:1,timeScale:1),
            constraints:constraints,maximumCoordinates:4,maximumRows:4,originalTolerance:1e-8)
        if impulse { return try MassWeightedMechanismSolver().reconcileVelocity(system,sample:sample,policy:policy,work:&outer,dynamicsWork:&dyn,rankWork:&rank,linearWork:&linear) }
        return try MassWeightedMechanismSolver().acceleration(system,sample:sample,drive:[0],policy:policy,work:&outer,dynamicsWork:&dyn,rankWork:&rank,linearWork:&linear)
    }
}
