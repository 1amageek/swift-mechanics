import SwiftMechanics

/// Actual calibrated spring and compiled inertia owners for public nonlinear continuation.
final class NonlinearStabilityProbeContext: Sendable {
    let source: NonlinearStabilitySource
    let policy: NonlinearStabilityPolicy
    let budget: NumericalBudget
    let firstIndex: Int
    let secondIndex: Int
    let thirdIndex: Int

    @inline(never)
    init() throws {
        let budget = try NumericalBudget(scalarStorage: 2_000_000,
            arithmeticOperations: 100_000_000, iterations: 100_000)
        self.budget = budget
        let limits = try EquilibriumLimits(coordinates: 3, rows: 1, cases: 1000, identifierBytes: 4096, bodies: 4)
        let nonlinear = try Self.nonlinear()
        let policy = try Self.policy(limits: limits, nonlinear: nonlinear)
        self.policy = policy
        let source = try Self.makeSource(limits: limits, nonlinear: nonlinear, budget: budget)
        self.source = source
        firstIndex = try Self.slot("nonlinear-stability-a-slider", compiled: source.compiled)
        secondIndex = try Self.slot("nonlinear-stability-b-slider", compiled: source.compiled)
        thirdIndex = try Self.slot("nonlinear-stability-c-slider", compiled: source.compiled)
    }

    func work() -> NumericalWork { NumericalWork(budget: budget) }

    @inline(never)
    func start(using service: any NonlinearStabilityContinuing, position: [Double], parameter: Double,
        initialDirection: [Double], work: inout NumericalWork) throws(NonlinearStabilityFailure) -> NonlinearStabilityState {
        try service.start(source, position: position, parameter: parameter, initialDirection: initialDirection,
            policy: policy, work: &work)
    }

    @inline(never)
    func advance(using service: any NonlinearStabilityContinuing, state: NonlinearStabilityState,
        arcStep: Double, work: inout NumericalWork) throws(NonlinearStabilityFailure) -> NonlinearStabilityState {
        try service.advance(source, state: state, arcStep: arcStep, policy: policy, work: &work)
    }

    @inline(never)
    func critical(using service: any NonlinearStabilityContinuing, left: NonlinearStabilityState,
        right: NonlinearStabilityState, work: inout NumericalWork) throws(NonlinearStabilityFailure) -> NonlinearStabilityCriticalPoint {
        try service.critical(source, left: left, right: right, policy: policy, work: &work)
    }

    @inline(never)
    private static func makeSource(limits: EquilibriumLimits, nonlinear: NonlinearPolicy<Double>,
        budget: NumericalBudget) throws -> NonlinearStabilitySource {
        let compiled = try compile()
        let chart = try chart(compiled, limits: limits)
        let model = try model(chart: chart, compiled: compiled, limits: limits)
        let constraints = try constraints(chart: chart, compiled: compiled, nonlinear: nonlinear)
        let branch = try EquilibriumBranch(identity: "nonlinear-stability-public-branches",
            minimumPosition: model.minimumPosition, maximumPosition: model.maximumPosition,
            maximumNormalizedStep: 0.3, limits: limits)
        var work = NumericalWork(budget: budget)
        return try NonlinearStabilitySource(model: model, constraints: constraints, compiled: compiled,
            branch: branch, time: 0, limits: limits, work: &work)
    }

    @inline(never)
    private static func chart(_ compiled: CompiledMechanicalModel, limits: EquilibriumLimits) throws -> StaticCoordinateChart {
        var joints: [EntityID] = []
        for i in 0..<3 {
            guard let entry = compiled.tree.layout.joints.first(where: { $0.positions.start == i }),
                  entry.positions.count == 1, entry.velocities.count == 1, entry.velocities.start == i else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            joints.append(entry.joint)
        }
        return try StaticCoordinateChart(stamp: compiled.stamp, frame: compiled.tree.worldFrame,
            coordinateIDs: [101, 102, 103], joints: joints, dimensions: [.length, .length, .length],
            scales: [1, 1, 1], limits: limits)
    }

    @inline(never)
    private static func model(chart: StaticCoordinateChart, compiled: CompiledMechanicalModel,
        limits: EquilibriumLimits) throws -> StaticForceModel {
        let first = try slot("nonlinear-stability-a-slider", compiled: compiled)
        let second = try slot("nonlinear-stability-b-slider", compiled: compiled)
        let third = try slot("nonlinear-stability-c-slider", compiled: compiled)
        var linear = [Double](repeating: 0, count: 3), cubic = linear, load = linear
        linear[first] = -1; linear[second] = -1; linear[third] = 1
        cubic[first] = 1; cubic[second] = 1
        load[first] = 1; load[second] = 1
        var lower = [Double](repeating: -3, count: 3), upper = [Double](repeating: 3, count: 3)
        lower[third] = -6; upper[third] = 6
        return try StaticForceModel(identity: "nonlinear-stability-original-springs", chart: chart,
            law: .springs(linear: linear, cubic: cubic, constant: [0, 0, 0], loadDirection: load),
            minimumPosition: lower, maximumPosition: upper, parameterIdentity: "nonlinear-stability-load-factor",
            minimumParameter: -10, maximumParameter: 10, energyScale: 1, limits: limits)
    }

    @inline(never)
    private static func constraints(chart: StaticCoordinateChart, compiled: CompiledMechanicalModel,
        nonlinear: NonlinearPolicy<Double>) throws -> StaticConstraints {
        let first = try slot("nonlinear-stability-a-slider", compiled: compiled)
        let second = try slot("nonlinear-stability-b-slider", compiled: compiled)
        let third = try slot("nonlinear-stability-c-slider", compiled: compiled)
        var row = [Double](repeating: 0, count: 3)
        row[first] = -1; row[second] = -1; row[third] = 1
        var lower = [Double](repeating: -3, count: 3), upper = [Double](repeating: 3, count: 3)
        lower[third] = -6; upper[third] = 6
        let system = try QuadraticConstraintSystem(layout: ConstraintCoordinateLayout(coordinateIDs: chart.coordinateIDs,
            dimensions: chart.dimensions, scales: chart.scales, timeScale: 1, revision: chart.stamp.revision),
            rows: [QuadraticConstraint(id: 11, constant: 0, linear: row, hessian: [Double](repeating: 0, count: 9),
                timeLinear: 0, timeQuadratic: 0, mixedTime: [0, 0, 0])],
            minimumPosition: lower, maximumPosition: upper, minimumTime: -1, maximumTime: 1)
        let policy = try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 3, maximumRows: 1,
            expectedLayoutRevision: chart.stamp.revision), diagonalMetric: [1, 1, 1], energyScale: 1,
            rankPolicy: .requireIndependentRows, rankRelativeTolerance: 1e-10, originalResidualTolerance: 1e-9,
            maximumCorrection: 0.3, nonlinear: nonlinear,
            linearCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            linearTolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-13))
        return StaticConstraints(system: system, policy: policy,
            responseBudget: try NumericalBudget(scalarStorage: 100000, arithmeticOperations: 10000000, iterations: 100))
    }

    @inline(never)
    private static func nonlinear() throws -> NonlinearPolicy<Double> {
        try NonlinearPolicy<Double>(strategy: .lineSearch(contraction: 0.5, sufficientDecrease: 1e-4, minimumFraction: 1e-10),
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            tolerance: LinearTolerance(absoluteResidual: 1e-11, relativeResidual: 0, pivotThreshold: 1e-13),
            referenceScale: 1, minimumDirectionNorm: 1e-15, derivativeProbeDistance: 1e-6,
            derivativeAbsoluteTolerance: 1e-4, derivativeRelativeTolerance: 1e-4,
            maximumFactorEntries: 256, estimateCondition: false,
            budget: NumericalBudget(scalarStorage: 100000, arithmeticOperations: 10000000, iterations: 100))
    }

    @inline(never)
    private static func policy(limits: EquilibriumLimits, nonlinear: NonlinearPolicy<Double>) throws -> NonlinearStabilityPolicy {
        let equilibrium = try EquilibriumPolicy(limits: limits, nonlinear: nonlinear,
            physicalForceTolerances: [1e-8, 1e-8, 1e-8], constraintTolerance: 1e-9,
            reactionSelection: .independentRowRepresentative)
        let evidence = try EquilibriumLinearizationPolicy(limits: limits,
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            tolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-13),
            displacementProbe: 1e-5, parameterProbe: 1e-5, derivativeAbsoluteTolerances: [1e-7, 1e-7, 1e-7],
            derivativeRelativeTolerance: 1e-6, constraintTolerance: 1e-9, inertialAbsoluteTolerances: [1e-9, 1e-9, 1e-9])
        let spectrum = try ComplexSpectrumPolicy(maximumDimension: 8, maximumQRIterations: 2000,
            deflationTolerance: 1e-13, eigenvectorPivotThreshold: 1e-13, originalResidualTolerance: 1e-8, isCancelled: { false })
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let dynamics = DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 4,
            maximumVelocities: 3, maximumBodyWrenches: 0, maximumGeneralizedContributions: 0),
            angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance)
        return try NonlinearStabilityPolicy(equilibrium: equilibrium, evidence: evidence, spectrum: spectrum,
            dynamics: dynamics, loadBudget: LoadBudget(maximumWork: 100000, maximumScalars: 1024), parameterScale: 1,
            arcTolerance: 1e-9, spectralTolerance: 1e-7, zeroStiffnessTolerance: 1e-7,
            loadProjectionTolerance: 1e-5, minimumMassPivot: 1e-12, maximumArcStep: 0.2, maximumCorrection: 0.3,
            maximumAcceptedPoints: 1000, maximumCriticalIterations: 80, criticalWidth: 1e-7)
    }

    private static func slot(_ key: String, compiled: CompiledMechanicalModel) throws -> Int {
        let id = try EntityID(kind: .joint, key: key)
        guard let entry = compiled.tree.layout.joints.first(where: { $0.joint == id }),
              entry.positions.count == 1, entry.velocities.count == 1, entry.positions.start == entry.velocities.start else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        return entry.positions.start
    }

    @inline(never)
    private static func body(_ key: String, mode: BodyMotionMode) throws -> BodyRecord3D {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let properties = try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .identity,
            policy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0))
        return try BodyRecord3D(id: EntityID(kind: .body, key: key), frame: EntityID(kind: .frame, key: key + "-frame"),
            mode: mode, bodyToWorld: .identity, representations: BodyRepresentations(),
            inertia: InertialRepresentation3D(properties: properties,
                provenance: SourceProvenance(source: "nonlinear-stability-unit-slider-inertia", revision: 1), quality: .exact))
    }

    @inline(never)
    private static func descriptor() throws -> MechanicalDescriptor {
        let root = try body("nonlinear-stability-root", mode: .static)
        var bodies: [MechanicalBody] = [.spatial(root)], joints: [MechanicalJoint] = []
        for suffix in ["a", "b", "c"] {
            let key = "nonlinear-stability-" + suffix
            let child = try body(key, mode: .dynamic)
            let joint = try JointRecord(id: EntityID(kind: .joint, key: key + "-slider"),
                parentBody: root.id, childBody: child.id,
                parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: key + "-parent"), placement: .fixed(.identity)),
                childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: key + "-child"), placement: .fixed(.identity)),
                manifold: JointManifold(.prismatic(axis: .unitY)))
            bodies.append(.spatial(child)); joints.append(MechanicalJoint(record: joint, authority: .dynamicState))
        }
        return try MechanicalDescriptor(identity: "nonlinear-stability-public-sliders", revision: 1,
            bodies: bodies, joints: joints, root: root.id, rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: EntityID(kind: .frame, key: "nonlinear-stability-world"),
            initialState: KinematicState(revision: 1, time: 0, q: [0, 0, 0], v: [0, 0, 0], acceleration: [0, 0, 0]),
            representationRequirements: [], features: [], extensions: [])
    }

    @inline(never)
    private static func compile() throws -> CompiledMechanicalModel {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 4,
            maximumVelocities: 3, maximumJacobianScalars: 72),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0),
            translationTolerance: tolerance, rotationTolerance: tolerance, maximumRecords: 64, maximumIdentifierBytes: 4096,
            maximumSparsityEntries: 72, maximumDependencyEntries: 1024, maximumExtensionRecords: 0, maximumDiagnostics: 4,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
        let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        return try compiler.compile(descriptor(), policy: policy)
    }
}
