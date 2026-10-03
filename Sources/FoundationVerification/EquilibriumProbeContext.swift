import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsNonlinear
import MechanicsConstraints
import MechanicsJoints
import MechanicsCompiler
import MechanicsLoads
import MechanicsDynamics
import MechanicsEquilibrium

struct EquilibriumProbeContext: Sendable {
    let limits: EquilibriumLimits
    let chart: StaticCoordinateChart
    let nonlinear: NonlinearPolicy<Double>
    let policy: EquilibriumPolicy
    let branch: EquilibriumBranch
    let budget: NumericalBudget

    @inline(never) init() throws {
        let limits = try EquilibriumLimits(coordinates: 2, rows: 4, cases: 4, identifierBytes: 256, bodies: 2)
        let chart = try StaticCoordinateChart(stamp: ModelStamp(identity: "equilibrium-public-probe", revision: 1),
            frame: EntityID(kind: .frame, key: "equilibrium-world"), coordinateIDs: [1],
            joints: [EntityID(kind: .joint, key: "equilibrium-hinge")], dimensions: [.angle], scales: [1], limits: limits)
        let nonlinear = try NonlinearPolicy<Double>(strategy: .lineSearch(contraction: 0.5, sufficientDecrease: 0.0001, minimumFraction: 1e-10),
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            tolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 0, pivotThreshold: 1e-12),
            referenceScale: 1, minimumDirectionNorm: 1e-15, derivativeProbeDistance: 1e-6,
            derivativeAbsoluteTolerance: 1e-4, derivativeRelativeTolerance: 1e-4, maximumFactorEntries: 64,
            estimateCondition: false, budget: NumericalBudget(scalarStorage: 100_000, arithmeticOperations: 1_000_000, iterations: 100))
        self.limits = limits
        self.chart = chart
        self.nonlinear = nonlinear
        policy = try EquilibriumPolicy(limits: limits, nonlinear: nonlinear, physicalForceTolerances: [1e-7],
            constraintTolerance: 1e-8, reactionSelection: .independentRowRepresentative)
        branch = try EquilibriumBranch(identity: "selected-local-branch", minimumPosition: [-3], maximumPosition: [3],
            maximumNormalizedStep: 1, limits: limits)
        budget = try NumericalBudget(scalarStorage: 300_000, arithmeticOperations: 10_000_000, iterations: 1000)
    }

    @inline(never) func spring() throws(EquilibriumError) -> StaticForceModel {
        try StaticForceModel(identity: "angular-spring", chart: chart,
            law: .springs(linear: [100], cubic: [0], constant: [49], loadDirection: [2]),
            minimumPosition: [-3], maximumPosition: [3], parameterIdentity: "load-factor",
            minimumParameter: -10, maximumParameter: 10, energyScale: 1, limits: limits)
    }

    @inline(never) func pendulum() throws(EquilibriumError) -> StaticForceModel {
        try StaticForceModel(identity: "pendulum", chart: chart, law: .pendulum(gravityMoment: 20, appliedMoment: 1),
            minimumPosition: [-1], maximumPosition: [1], parameterIdentity: "torque-factor",
            minimumParameter: -10, maximumParameter: 10, energyScale: 1, limits: limits)
    }

    @inline(never) func supports() throws -> StaticConstraints {
        let system = try QuadraticConstraintSystem(layout: ConstraintCoordinateLayout(coordinateIDs: chart.coordinateIDs,
            dimensions: chart.dimensions, scales: chart.scales, timeScale: 1, revision: chart.stamp.revision),
            rows: [QuadraticConstraint(id: 100, constant: 0, linear: [1], hessian: [0], timeLinear: 0, timeQuadratic: 0, mixedTime: [0]),
                   QuadraticConstraint(id: 101, constant: 0, linear: [2], hessian: [0], timeLinear: 0, timeQuadratic: 0, mixedTime: [0])],
            minimumPosition: [-3], maximumPosition: [3], minimumTime: -1, maximumTime: 1)
        let p = try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 2, maximumRows: 4,
            expectedLayoutRevision: chart.stamp.revision), diagonalMetric: [1], energyScale: 1, rankPolicy: .allowRedundancy,
            rankRelativeTolerance: 1e-10, originalResidualTolerance: 1e-8, maximumCorrection: 1, nonlinear: nonlinear,
            linearCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            linearTolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-12))
        return StaticConstraints(system: system, policy: p,
            responseBudget: try NumericalBudget(scalarStorage: 10_000, arithmeticOperations: 100_000, iterations: 0))
    }

    @inline(never) func body(_ name: String, mass: Double, center: Vector3, mode: BodyMotionMode) throws -> BodyRecord3D {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let properties = try MassProperties3D(mass: mass, centerOfMass: center, inertiaAtCenter: .identity,
            policy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0))
        return try BodyRecord3D(id: EntityID(kind: .body, key: name), frame: EntityID(kind: .frame, key: name + "-frame"), mode: mode,
            bodyToWorld: .identity, representations: BodyRepresentations(), inertia: InertialRepresentation3D(properties: properties,
                provenance: SourceProvenance(source: "equilibrium-analytic-fixture", revision: 1), quality: .exact))
    }

    @inline(never) func descriptor() throws -> MechanicalDescriptor {
        let root = try body("equilibrium-root", mass: 1, center: .zero, mode: .static)
        let child = try body("equilibrium-child", mass: 2, center: Vector3(0, -1, 0), mode: .dynamic)
        let record = try JointRecord(id: chart.joints[0], parentBody: root.id, childBody: child.id,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "equilibrium-parent-anchor"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "equilibrium-child-anchor"), placement: .fixed(.identity)),
            manifold: JointManifold(.revolute(axis: .unitZ)))
        // Descriptor ordering deliberately differs from the actual articulated body ordering.
        return try MechanicalDescriptor(identity: chart.stamp.identity, revision: chart.stamp.revision,
            bodies: [.spatial(child), .spatial(root)], joints: [MechanicalJoint(record: record, authority: .dynamicState)],
            root: root.id, rootBase: .fixed, rootAuthority: .fixed, worldFrame: chart.frame,
            initialState: KinematicState(revision: chart.stamp.revision, time: 0, q: [0], v: [0], acceleration: [0]),
            representationRequirements: [], features: [], extensions: [])
    }

    @inline(never) func compile() throws -> CompiledMechanicalModel {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let p = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0), translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 20, maximumIdentifierBytes: 2000, maximumSparsityEntries: 12, maximumDependencyEntries: 200,
            maximumExtensionRecords: 0, maximumDiagnostics: 4,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10), target: FoundationVerification.compilerVerificationTarget)
        let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        return try compiler.compile(descriptor(), policy: p)
    }

    @inline(never) func mass(_ compiled: CompiledMechanicalModel, point: EquilibriumSolution) throws -> RigidDynamicsSystem {
        let state = try KinematicState(revision: chart.stamp.revision, time: point.time, q: point.position, v: [0], acceleration: [0])
        let snapshot = try compiled.evaluate(compiled.makeState(state))
        var inertias: [RigidBodyInertia] = []
        for body in snapshot.bodies {
            guard let descriptor = compiled.descriptor.bodies.first(where: { $0.id == body.body }),
                  case .spatial(let record) = descriptor, let inertia = record.inertia,
                  record.frame == body.bodyFrame else { throw DynamicsError.inertiaIdentityMismatch }
            inertias.append(try RigidBodyInertia(body: body.body, frame: body.bodyFrame, properties: inertia.properties))
        }
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let admission = DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 2, maximumVelocities: 1,
            maximumBodyWrenches: 0, maximumGeneralizedContributions: 0), angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance)
        var loadWork = LoadWork(budget: try LoadBudget(maximumWork: 100, maximumScalars: 0))
        var work = NumericalWork(budget: budget)
        let equations: any RigidEquationComputing = RigidEquationKernel()
        return try equations.assemble(RigidDynamicsInput(snapshot: snapshot, velocity: [0], inertias: inertias, gravity: nil),
            admission: admission, loadWork: &loadWork, work: &work)
    }
}

