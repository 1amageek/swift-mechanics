import SwiftMechanics

public struct LinearQuadraticQualificationMechanical: Sendable {
    public let model: CompiledMechanicalModel
    public let source: EquilibriumLinearization
    public let system: DiscreteControlSystem
    public let port: ScalarControlPort
    public let admission: DynamicsAdmission
    public let solve: DynamicsSolvePolicy

    public init() throws {
        let limits = try EquilibriumLimits(coordinates: 2, rows: 2, cases: 2, identifierBytes: 256, bodies: 2)
        let world = try Self.id(.frame, "world"), joint = try Self.id(.joint, "slide")
        let parent = try Self.id(.frame, "parent"), childAnchor = try Self.id(.frame, "child-anchor")
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        var records: [BodyRecord3D] = []
        for i in 0..<2 {
            let properties = try MassProperties3D(mass: i == 0 ? 1 : 2, centerOfMass: Vector3(0.2, -0.1, 0.3),
                inertiaAtCenter: Matrix3(2, 0.1, 0, 0.1, 3, 0.2, 0, 0.2, 3.5), policy: inertiaPolicy)
            records.append(try BodyRecord3D(id: Self.id(.body, "body-\(i)"), frame: Self.id(.frame, "body-\(i)"),
                mode: i == 0 ? .static : .dynamic, bodyToWorld: RigidTransform(rotation: .identity, translation: Vector3(i == 0 ? 0 : 0.5, 0, 0)), representations: BodyRepresentations(),
                inertia: InertialRepresentation3D(properties: properties, provenance: SourceProvenance(source: "lqr-physical-mass", revision: 7), quality: .exact)))
        }
        let record = try JointRecord(id: joint, parentBody: records[0].id, childBody: records[1].id,
            parentAnchor: JointAnchor(frame: parent, placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: childAnchor, placement: .fixed(.identity)), manifold: JointManifold(.prismatic(axis: .unitX)))
        let descriptor = try MechanicalDescriptor(identity: "lqr-physical-prismatic", revision: 7,
            bodies: [.spatial(records[1]), .spatial(records[0])], joints: [MechanicalJoint(record: record, authority: .dynamicState)],
            root: records[0].id, rootBase: .fixed, rootAuthority: .fixed, worldFrame: world,
            initialState: KinematicState(revision: 7, time: 3, q: [0.5], v: [0], acceleration: [0]),
            representationRequirements: [], features: [], extensions: [])
        let compilation = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 20, maximumIdentifierBytes: 2000, maximumSparsityEntries: 12, maximumDependencyEntries: 200,
            maximumExtensionRecords: 0, maximumDiagnostics: 4,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10), target: Self.target)
        let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        model = try compiler.compile(descriptor, policy: compilation)
        let chart = try StaticCoordinateChart(stamp: model.stamp, frame: world, coordinateIDs: [1], joints: [joint], dimensions: [.length], scales: [0.25], limits: limits)
        let force = try StaticForceModel(identity: "lqr-spring8-load2", chart: chart,
            law: .springs(linear: [8], cubic: [0], constant: [0], loadDirection: [2]), minimumPosition: [-2], maximumPosition: [2],
            parameterIdentity: "explicit-2N-per-parameter-unit", minimumParameter: -4, maximumParameter: 4, energyScale: 1, limits: limits)
        let nonlinear = try NonlinearPolicy<Double>(strategy: .lineSearch(contraction: 0.5, sufficientDecrease: 0.0001, minimumFraction: 1e-10),
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            tolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 0, pivotThreshold: 1e-12), referenceScale: 1,
            minimumDirectionNorm: 1e-15, derivativeProbeDistance: 1e-6, derivativeAbsoluteTolerance: 1e-4, derivativeRelativeTolerance: 1e-4,
            maximumFactorEntries: 64, estimateCondition: false, budget: NumericalBudget(scalarStorage: 100_000, arithmeticOperations: 1_000_000, iterations: 100))
        let equilibrium = try EquilibriumPolicy(limits: limits, nonlinear: nonlinear, physicalForceTolerances: [1e-8],
            constraintTolerance: 1e-8, reactionSelection: .independentRowRepresentative)
        let branch = try EquilibriumBranch(identity: "lqr-selected-spring", minimumPosition: [-2], maximumPosition: [2], maximumNormalizedStep: 1, limits: limits)
        var work = try Self.work()
        let solver: any EquilibriumSolving = ReferenceEquilibriumSolver()
        let point = try solver.solve(force, constraints: nil, initialPosition: [0.4], parameter: 2, time: 3, branch: branch, policy: equilibrium, work: &work)
        admission = DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 2, maximumVelocities: 1, maximumBodyWrenches: 0, maximumGeneralizedContributions: 1),
            angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance)
        solve = try DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            linearTolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-12), coordinateScales: [1], energyScale: 1, timeScale: 1)
        let mass = try Self.assemble(model, position: point.position[0], rate: 0, force: nil, admission: admission)
        let reduction = EquilibriumReduction(freeCoordinates: 1, basis: [0.5], damping: [2], outputRows: 1, outputMap: [1], outputDimensions: [.length])
        let linearization = try EquilibriumLinearizationPolicy(limits: limits,
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            tolerance: LinearTolerance(absoluteResidual: 1e-9, relativeResidual: 1e-10, pivotThreshold: 1e-12),
            displacementProbe: 1e-5, parameterProbe: 1e-5, derivativeAbsoluteTolerances: [1e-5], derivativeRelativeTolerance: 1e-6,
            constraintTolerance: 1e-8, inertialAbsoluteTolerances: [1e-9])
        let linearizer: any EquilibriumLinearizing = ReferenceEquilibriumLinearizer()
        source = try linearizer.linearize(point, compiled: model, dynamics: mass, reduction: reduction, policy: linearization, work: &work)
        let controlPolicy = try LinearQuadraticQualificationFixture.policy()
        var controlWork = try LinearQuadraticQualificationFixture.work(controlPolicy)
        let preparer: any DiscreteControlSystemPreparing = ReferenceDiscreteControlSystemPreparer()
        system = try preparer.bilinear(source, identity: "lqr-physical-bilinear", samplePeriodSeconds: 0.1, stateScales: [0.2, 0.4],
            inputDimension: .force, inputScale: 3, parameterChangePerInputUnit: 0.5, policy: controlPolicy, work: &controlWork)
        let binding = try ActuatorBinding(actuator: Self.id(.actuator, "effort"), joint: joint, frame: world, model: model.stamp,
            lawRevision: 1, continuationKey: 99, positionIndex: 0, velocityIndex: 0, coordinate: .translation, authority: .dynamicState,
            stateKind: .servo, stateDomain: ActuatorScalarDomain(primaryLower: -2, primaryUpper: 2, secondaryLower: -10, secondaryUpper: 10))
        var actuation = try ActuationWork(budget: Self.actuationBudget())
        try binding.validate(model: model, work: &actuation)
        port = try ScalarControlPort(binding: binding, parentAnchorFrame: parent)
    }
    private static var target: CompilerTarget {
        #if arch(wasm32)
        #if hasFeature(Embedded)
        .embeddedWasiPreview1
        #else
        .wasiPreview1
        #endif
        #else
        .nativeCPU
        #endif
    }
    public static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: "lqr-" + key) }
    public static func work() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 300_000, arithmeticOperations: 10_000_000, iterations: 1000))
    }
    private static func assemble(_ model: CompiledMechanicalModel, position: Double, rate: Double, force: Double?,
        admission: DynamicsAdmission) throws -> RigidDynamicsSystem {
        let state = try KinematicState(revision: model.stamp.revision, time: 3, q: [position], v: [rate], acceleration: [0])
        let snapshot = try model.evaluate(model.makeState(state))
        var inertias: [RigidBodyInertia] = []
        for body in snapshot.bodies {
            guard let descriptor = model.descriptor.bodies.first(where: { $0.id == body.body }),
                case .spatial(let record) = descriptor, let inertia = record.inertia else { throw DynamicsError.inertiaIdentityMismatch }
            inertias.append(try RigidBodyInertia(body: body.body, frame: body.bodyFrame, properties: inertia.properties))
        }
        var forces: [GeneralizedForceContribution] = []
        if let force { forces.append(try GeneralizedForceContribution(values: [force], channel: .applied, potentialEnergy: 4*position*position, dissipatedPower: 2*rate*rate)) }
        var loads = LoadWork(budget: try LoadBudget(maximumWork: 1000, maximumScalars: 100)), work = try Self.work()
        let equations: any RigidEquationComputing = RigidEquationKernel()
        return try equations.assemble(RigidDynamicsInput(snapshot: snapshot, velocity: [rate], inertias: inertias,
            gravity: nil, generalizedForces: forces), admission: admission, loadWork: &loads, work: &work)
    }
    public func feedback(position: Double = 0.55, rate: Double = -0.1) throws -> ScalarControlFeedback {
        let state = try model.makeState(KinematicState(revision: model.stamp.revision, time: 3, q: [position], v: [rate], acceleration: [0]))
        let observationPolicy = try ObservationPolicy(maximumBodies: 2, maximumCoordinates: 2, maximumReactionRows: 0, maximumMetadataBytes: 8192)
        var work = try Self.work()
        let preparer: any ObservationSourcePreparing = ReferenceObservationSourcePreparer()
        let source = try preparer.prepare(model: model, state: state, solved: nil, policy: observationPolicy, work: &work)
        let observer: any KinematicObserving = ReferenceKinematicObserver()
        let encoder = try observer.encoder(source: source, joint: port.binding.joint, policy: observationPolicy, work: &work)
        let adapter: any ControlPortPreparing = ReferenceControlPortAdapter()
        return try adapter.prepare(encoder: encoder, port: port, policy: Self.portPolicy(admission: admission, solve: solve), work: &work)
    }
    public func originalOutcome(effort: Double, position: Double = 0.55, rate: Double = -0.1) throws -> (solution: DynamicsSolution, energy: MechanicalEnergy) {
        let force = effort-8*position-2*rate
        let system = try Self.assemble(model, position: position, rate: rate, force: force, admission: admission)
        let equations: any RigidEquationComputing = RigidEquationKernel(), solver: any RigidDynamicsSolving = DenseRigidDynamics()
        var work = try Self.work()
        let solution = try solver.forward(system, driveForce: [0], policy: solve, work: &work)
        let energy = try equations.energy(system, acceleration: solution.acceleration, angularMomentumReference: .zero, requireComplete: false, work: &work)
        return (solution, energy)
    }
    private static func actuationBudget() throws -> ActuationBudget {
        try ActuationBudget(maximumWork: 100_000, maximumScalars: 1000, maximumBytes: 16_384, maximumBindings: 4, maximumMetadataBytes: 8192)
    }
    private static func portPolicy(admission: DynamicsAdmission, solve: DynamicsSolvePolicy) throws -> ControlPolicy {
        let numerical = try NumericalBudget(scalarStorage: 100_000, arithmeticOperations: 10_000_000, iterations: 10_000)
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let integration = try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: 0.1, minimumStep: 1e-8, maximumStep: 0.1,
            safety: 0.8, minimumFactor: 0.1, maximumFactor: 2,
            scales: [ODEErrorScale(dimension: .length, absoluteSI: 1e-10, relative: 0), ODEErrorScale(dimension: .velocity, absoluteSI: 1e-10, relative: 0)],
            maximumContinuationBytes: 4096, budget: IntegrationBudget(maximumCoordinates: 2, maximumAttempts: 16, maximumAcceptedSteps: 16,
                maximumOuterArithmetic: 100_000, supplier: numerical))
        let capacity = try RuntimeCapacity(maximumPhysicalScalars: 3, maximumContributors: 3, maximumContributorBytes: 16_384,
            maximumMetadataBytes: 16_384, maximumCheckpointBytes: 32_768, maximumValidationWork: 100_000,
            maximumValidationScratchBytes: 16_384, maximumObservationLeases: 2, maximumBatchStates: 1,
            maximumTransactions: 100, maximumStepWorkUnits: 100_000, maximumWorkBetweenSafePoints: 64)
        return try ControlPolicy(maximumMetadataBytes: 8192, maximumGraphNodes: 4, maximumGraphEdges: 4, maximumPayloadBytes: 16_384,
            maximumPositionMeters: 2, maximumRateMetersPerSecond: 10, agreement: tolerance, actuation: actuationBudget(), numerical: numerical,
            dynamics: solve, admission: admission, inertia: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0),
            integration: integration, runtimeCapacity: capacity,
            continuation: RuntimeContinuationIdentity(build: "lqr-encoder-only", backend: "referenceCPU", precision: "float64"))
    }
}
