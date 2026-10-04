import SwiftMechanics

/// Actual producer fixture. Physical assertions live in the independent test suites.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct PlanarPrescribedRootReactionFixtures {
    let model: CompiledMechanicalModel
    let geometry: GeometricConstraintSystem
    let state: KinematicState
    let constraint: PrescribedRootConstraint
    let motion: PhysicalConstrainedMotion
    let policy: PlanarPrescribedRootReactionPolicy
    let input: PlanarPrescribedRootReactionInput
    static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func work(storage: Int = 1_000_000, operations: Int = 20_000_000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:100_000))
    }
    static func loads(prefix: Int = 0, cancel: @escaping @Sendable () -> Bool = { false }) throws -> LoadWork {
        var work=LoadWork(budget:try LoadBudget(maximumWork:1000,maximumScalars:0,isCancelled:cancel))
        try work.charge(prefix);return work
    }
    @inline(never)
    init(slider: Bool = false, time: Double = 0.2, scale: Double = 1, gravity: Bool = false,
         angularAcceleration: Double = 0.3, bodyLoads: [BodyWrenchContribution] = [], generalized: Bool = false,
         dynamicDrive: Double = 0, rootID: UInt64 = 101, relations: [GeometricRelation] = []) throws {
        let built=try Self.buildModel(slider:slider,angularAcceleration:angularAcceleration)
        model=built.0
        var work=try Self.work()
        let base=try AnalyticPrescribedBaseMotionSampler().sampleBase(built.1,time:time,policy:built.1.policy,work:&work)
        state=try KinematicState(revision:1,time:time,q:base.q+(slider ? [0] : []),v:base.v+(slider ? [0] : []),acceleration:base.a+(slider ? [0] : []))
        let n=state.v.count,dimensions:[PhysicalDimension]=[.length,.length,.angle]+(slider ? [.length] : [])
        let scales=(0..<n).map { scale*Double($0+2) }
        let layout=try ConstraintCoordinateLayout(coordinateIDs:(0..<n).map { UInt64(301+$0) },dimensions:dimensions,scales:scales,timeScale:2,revision:1)
        geometry=try GeometricConstraintSystem(model:model,layout:layout,relations:relations,minimumPosition:[Double](repeating:-100,count:state.q.count),
            maximumPosition:[Double](repeating:100,count:state.q.count),minimumTime:0,maximumTime:2,
            capacity:GeometricConstraintCapacity(maximumBodies:8,maximumPositions:16,maximumVelocities:8,maximumRows:12,maximumMetadataBytes:50_000),
            work:&work,prescribedBase:built.1,rootRowIDs:[rootID,rootID+1,rootID+2])
        let policies=try Self.policies(scales)
        policy=policies
        let system=try Self.assemble(model,state:state,gravity:gravity,bodyLoads:bodyLoads,generalized:generalized)
        let sample=try GeometricRelationEvaluator().evaluate(geometry,state:state,policy:policies.geometry,work:&work)
        guard let binding=geometry.prescribedRoot else { throw ReactionPathError.invalidInput }
        constraint=try PrescribedRootConstraint(system:system,geometry:sample.velocity,base:base,rowIDs:binding.rowIDs,policy:policies.mechanism,work:&work)
        var drive=[Double](repeating:0,count:n);if slider { drive[3]=dynamicDrive }
        motion=try Self.solve(constraint,drive:drive,policy:policies.mechanism)
        input=PlanarPrescribedRootReactionInput(motion:motion,geometry:geometry,state:state,constraint:constraint,originalDrive:[Double](repeating:0,count:n),topology:.completeTree)
    }
    @inline(never)
    private static func buildModel(slider: Bool, angularAcceleration: Double) throws -> (CompiledMechanicalModel,PrescribedBaseMotionProgram) {
        let root=try id(.body,"support-root"),rootFrame=try id(.frame,"support-root-frame"),world=try id(.frame,"support-world")
        let pose=RigidTransform(rotation:try UnitQuaternion(axis:.unitZ,angle:slider ? 0 : 0.4),translation:try Vector3(slider ? 0 : 1,slider ? 0 : 2,0))
        let law=try AnalyticPrescribedMotion(frame:rootFrame,parentFrame:world,referenceTime:0,initialPose:pose,
            translationRate:slider ? .zero : Vector3(0.4,-0.2,0),translationAcceleration:slider ? Vector3(0,1,0) : Vector3(0.3,0.2,0),
            rotationAxis:.unitZ,angularRate:slider ? 0 : 0.2,angularAcceleration:slider ? 0 : angularAcceleration,minimumTime:0,maximumTime:2,maximumIdentifierBytes:100)
        let mp=try PrescribedMotionPolicy(maximumSamples:1,maximumIdentifierBytes:100,maximumMetadataBytes:8192)
        var work=try Self.work()
        let program=try PrescribedBaseMotionProgram(law:law,layout:.planarFloating,policy:mp,work:&work)
        let base=try AnalyticPrescribedBaseMotionSampler().sampleBase(program,time:0,policy:mp,work:&work)
        let provenance=try SourceProvenance(source:"independent-prescribed-support",revision:1)
        let properties=try MassProperties2D(mass:slider ? 1 : 2,centerX:slider ? 0 : 0.4,centerY:slider ? 0 : -0.3,polarInertiaAtCenter:slider ? 1 : 5)
        var bodies:[MechanicalBody]=[.planar(try BodyRecord2D(id:root,frame:rootFrame,mode:.prescribedKinematic,
            bodyToWorld:PlanarPose(x:pose.translation.x,y:pose.translation.y,angle:slider ? 0 : 0.4),representations:BodyRepresentations(),
            inertia:InertialRepresentation2D(properties:properties,provenance:provenance,quality:.exact)))]
        var joints:[MechanicalJoint]=[]
        if slider {
            let child=try id(.body,"support-child")
            bodies.append(.planar(try BodyRecord2D(id:child,frame:id(.frame,"support-child-frame"),mode:.dynamic,
                bodyToWorld:PlanarPose(x:2,y:0,angle:0),representations:BodyRepresentations(),
                inertia:InertialRepresentation2D(properties:MassProperties2D(mass:2,centerX:0,centerY:0,polarInertiaAtCenter:1),provenance:provenance,quality:.exact))))
            let joint=try JointRecord(id:id(.joint,"support-slide"),parentBody:root,childBody:child,
                parentAnchor:JointAnchor(frame:id(.frame,"support-slide-parent"),placement:.fixed(RigidTransform(rotation:.identity,translation:Vector3(2,0,0)))),
                childAnchor:JointAnchor(frame:id(.frame,"support-slide-child"),placement:.fixed(.identity)),manifold:JointManifold(.prismatic(axis:.unitX)))
            joints.append(MechanicalJoint(record:joint,authority:.dynamicState))
        }
        let initial=try KinematicState(revision:1,time:0,q:base.q+(slider ? [0] : []),v:base.v+(slider ? [0] : []),acceleration:base.a+(slider ? [0] : []))
        let descriptor=try MechanicalDescriptor(identity:"prescribed-support-oracle",revision:1,bodies:bodies,joints:joints,root:root,rootBase:.planarFloating,
            rootAuthority:.prescribedMotion,worldFrame:world,initialState:initial,representationRequirements:[],features:[],extensions:[])
        let t=try NumericalTolerance(absolute:1e-12,relative:1e-12)
        let cp=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:8,maximumVelocities:8,maximumJacobianScalars:1000),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:t,chartRankRelative:1e-10,characteristicLengthMeters:1),
            inertiaPolicy:InertiaValidationPolicy(symmetry:t,physicalityRelative:0),translationTolerance:t,rotationTolerance:t,
            maximumRecords:100,maximumIdentifierBytes:10_000,maximumSparsityEntries:1000,maximumDependencyEntries:1000,maximumExtensionRecords:8,
            maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        return (try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:cp),program)
    }
    @inline(never)
    static func assemble(_ model: CompiledMechanicalModel, state: KinematicState, gravity: Bool = false,
                         bodyLoads: [BodyWrenchContribution] = [], generalized: Bool = false) throws -> PhysicalRigidDynamicsSystem {
        let snapshot=try model.evaluate(model.makeState(state))
        var inertias:[PlanarRigidBodyInertia]=[]
        for body in snapshot.bodies {
            guard let record=model.descriptor.bodies.first(where:{$0.id == body.body}),case .planar(let raw)=record,let p=raw.inertia?.properties else { throw ReactionPathError.invalidInput }
            inertias.append(try PlanarRigidBodyInertia(body:raw.id,frame:raw.frame,properties:p))
        }
        let field=gravity ? try AffineGravity(frame:snapshot.tree.worldFrame,accelerationAtOrigin:Vector3(0,-10,0)) : nil
        let gs=generalized ? [try GeneralizedForceContribution(values:[Double](repeating:1,count:state.v.count),channel:.actuator)] : []
        let input=try PhysicalRigidDynamicsInput(planar:PlanarRigidDynamicsInput(snapshot:snapshot,velocity:state.v,inertias:inertias,gravity:field,bodyWrenches:bodyLoads,generalizedForces:gs))
        var work=try Self.work(),loads=try Self.loads()
        return try RigidEquationKernel().assemble(input,admission:ReactionFixtures.admission(),loadWork:&loads,work:&work)
    }
    static func policies(_ scales: [Double], cancelled: Bool = false) throws -> PlanarPrescribedRootReactionPolicy {
        let n=scales.count,ev=try ConstraintEvaluationPolicy(maximumCoordinates:8,maximumRows:12,expectedLayoutRevision:1)
        let linear=try LinearTolerance<Double>(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:1e-13)
        let nonlinear=try NonlinearPolicy<Double>(strategy:.lineSearch(contraction:0.5,sufficientDecrease:1e-4,minimumFraction:1e-7),
            capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),tolerance:linear,referenceScale:1,
            minimumDirectionNorm:0,derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-4,derivativeRelativeTolerance:1e-4,
            maximumFactorEntries:1000,estimateCondition:false,budget:Self.work().budget)
        let constraints=try ConstraintSolvePolicy(evaluation:ev,diagonalMetric:[Double](repeating:1,count:n),energyScale:7,rankPolicy:.allowRedundancy,
            rankRelativeTolerance:1e-10,originalResidualTolerance:1e-8,maximumCorrection:100,nonlinear:nonlinear,
            linearCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),linearTolerance:linear)
        let dynamics=try DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),linearTolerance:linear,
            coordinateScales:scales,energyScale:7,timeScale:2)
        let mechanism=try MechanismSolvePolicy(dynamics:dynamics,constraints:constraints,maximumCoordinates:8,maximumRows:12,originalTolerance:1e-8,isCancelled:{cancelled})
        let t=try NumericalTolerance(absolute:1e-9,relative:1e-10)
        let tree=try TreeReactionPolicy(maximumBodies:8,maximumJoints:8,maximumBodyLoads:20,generalizedForceScales:[Double](repeating:1,count:n),generalizedTolerance:t,forceTolerance:t,torqueTolerance:t)
        return try PlanarPrescribedRootReactionPolicy(geometry:ev,mechanism:mechanism,tree:tree)
    }
    @inline(never)
    static func solve(_ c: PrescribedRootConstraint, drive: [Double], policy: MechanismSolvePolicy,
                      equations: any PhysicalRigidEquationComputing = RigidEquationKernel(), impulse: Bool = false) throws -> PhysicalConstrainedMotion {
        let solver:any PrescribedRootMechanismSolving=MassWeightedMechanismSolver(physicalDynamics:DenseRigidDynamics(physicalEquations:RigidEquationKernel()),physicalEquations:equations)
        var work=try Self.work(),dynamics=try Self.work(),rank=try Self.work(),linear=try Self.work()
        if impulse { return try solver.reconcileVelocity(c,policy:policy,work:&work,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear) }
        return try solver.acceleration(c,drive:drive,policy:policy,work:&work,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear)
    }
    func replacing(motion: PhysicalConstrainedMotion? = nil, geometry: GeometricConstraintSystem? = nil, state: KinematicState? = nil,
                   constraint: PrescribedRootConstraint? = nil, drive: [Double]? = nil, topology: TreeReactionTopology = .completeTree) -> PlanarPrescribedRootReactionInput {
        PlanarPrescribedRootReactionInput(motion:motion ?? self.motion,geometry:geometry ?? self.geometry,state:state ?? self.state,
            constraint:constraint ?? self.constraint,originalDrive:drive ?? input.originalDrive,topology:topology)
    }
    @inline(never)
    func recover(_ input: PlanarPrescribedRootReactionInput? = nil, frame: EntityID? = nil,
                 recovery: any PlanarPrescribedRootReactionRecovering = PlanarPrescribedRootReactionRecovery()) throws -> PlanarPrescribedRootReactionReport {
        var work=try Self.work(),loads=try Self.loads()
        return try recovery.recover(input ?? self.input,outputFrame:frame ?? model.tree.worldFrame,policy:policy,loadWork:&loads,work:&work)
    }
    static func foreign(_ system: PhysicalRigidDynamicsSystem, mass: Double = 3) throws -> PhysicalRigidDynamicsSystem {
        guard case .planar(let original)=system.input.source else { throw ReactionPathError.invalidInput }
        var inertias=original.inertias
        let p=inertias[0]
        inertias[0]=try PlanarRigidBodyInertia(body:p.body,frame:p.frame,properties:MassProperties2D(mass:mass,centerX:p.properties.centerX,centerY:p.properties.centerY,polarInertiaAtCenter:p.properties.polarInertiaAtCenter))
        let input=try PhysicalRigidDynamicsInput(planar:PlanarRigidDynamicsInput(snapshot:original.snapshot,velocity:original.velocity,inertias:inertias,
            gravity:original.gravity,bodyWrenches:original.bodyWrenches,generalizedForces:original.generalizedForces))
        var work=try Self.work(),loads=try Self.loads()
        return try RigidEquationKernel().assemble(input,admission:ReactionFixtures.admission(),loadWork:&loads,work:&work)
    }
}
