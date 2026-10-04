import SwiftMechanics

/// Each actual construction, reconciliation and runtime operation has a separate stack phase.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class QuadraticColdProbeContext: Sendable {
    typealias Session = RuntimeSession<NonlinearMechanismCheckpointHandler>
    let fixture: QuadraticColdProbeModel
    let sourceEquations: NonlinearMechanismEquation
    let release: SubtreeRelease
    let equations: NonlinearMechanismEquation
    let reconciled: NonlinearReconciledSubtreeRelease
    let continuation: IntegrationContinuationProvider
    let handler: NonlinearMechanismCheckpointHandler
    let configuration: RuntimeConfiguration
    let bPosition: Int
    let cPosition: Int
    let bVelocity: Int
    let cVelocity: Int
    let freePositions: CoordinateRange
    let freeVelocities: CoordinateRange

    @inline(never)
    init(fixture: QuadraticColdProbeModel) throws {
        self.fixture = fixture
        sourceEquations = try Self.sourceEquation(fixture)
        let release = try Self.release(fixture)
        self.release = release
        let equations = try Self.equation(release.target, bJoint: fixture.bJoint, cJoint: fixture.cJoint)
        self.equations = equations
        reconciled = try Self.prepare(release: release, equations: equations)
        let continuation = try Self.continuation(equations)
        self.continuation = continuation
        handler = try Self.handler(equations: equations, continuation: continuation)
        configuration = try Self.configuration(continuation)
        let b = try Self.entry(fixture.bJoint, model: release.target), c = try Self.entry(fixture.cJoint, model: release.target)
        let free = try Self.entry(release.connector, model: release.target)
        bPosition = b.positions.start; cPosition = c.positions.start
        bVelocity = b.velocities.start; cVelocity = c.velocities.start
        freePositions = free.positions; freeVelocities = free.velocities
    }

    @inline(never)
    static func sourceEquation(_ fixture: QuadraticColdProbeModel) throws -> NonlinearMechanismEquation {
        let velocity = try ConstraintCoordinateLayout(coordinateIDs: [101, 102, 103], dimensions: [.length, .length, .length],
            scales: [1, 1, 1], timeScale: 1, revision: fixture.model.stamp.revision)
        return try makeEquation(identity: "quadratic-cold-source-rest", model: fixture.model,
            constraints: fixture.constraints, velocityLayout: velocity, drive: fixture.drive)
    }

    @inline(never)
    static func release(_ fixture: QuadraticColdProbeModel) throws -> SubtreeRelease {
        let state = try fixture.model.makeState(fixture.model.descriptor.initialState)
        var outer = try TopologyProbeContext.work(), dynamics = try TopologyProbeContext.work()
        let service: any SubtreeReleaseBuilding = ReferenceSubtreeReleaseBuilder()
        return try service.release(model: fixture.model, state: state, joint: fixture.aJoint,
            connector: EntityID(kind: .joint, key: "quadratic-cold-free-a"),
            parentAnchor: EntityID(kind: .frame, key: "quadratic-cold-free-a-parent"),
            childAnchor: EntityID(kind: .frame, key: "quadratic-cold-free-a-child"),
            policy: TopologyProbeContext.policy(), admission: TopologyProbeContext.admission(),
            work: &outer, dynamicsWork: &dynamics)
    }

    @inline(never)
    static func equation(_ target: CompiledMechanicalModel, bJoint: EntityID, cJoint: EntityID) throws -> NonlinearMechanismEquation {
        let p = target.tree.layout.positionCount, n = target.tree.layout.velocityCount
        guard p > 0, p <= 16, n > 0, n <= 16 else { throw FoundationVerificationError.analyticCheckFailed }
        var qDimensions = [PhysicalDimension](repeating: .length, count: p)
        var vDimensions = [PhysicalDimension](repeating: .length, count: n)
        for entry in target.tree.layout.joints {
            guard let joint = target.tree.joints.first(where: { $0.id == entry.joint }) else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            switch joint.manifold.kind {
            case .sixDOF:
                guard entry.positions.count == 7, entry.velocities.count == 6 else { throw FoundationVerificationError.analyticCheckFailed }
                for i in 3..<7 { qDimensions[entry.positions.start + i] = .dimensionless }
                for i in 3..<6 { vDimensions[entry.velocities.start + i] = .angle }
            case .prismatic:
                guard entry.positions.count == 1, entry.velocities.count == 1 else { throw FoundationVerificationError.analyticCheckFailed }
            default: throw FoundationVerificationError.analyticCheckFailed
            }
        }
        let b = try entry(bJoint, model: target), c = try entry(cJoint, model: target)
        guard b.positions.count == 1, b.velocities.count == 1, c.positions.count == 1, c.velocities.count == 1 else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let positions = try ConstraintCoordinateLayout(coordinateIDs: (0..<p).map { UInt64($0 + 101) },
            dimensions: qDimensions, scales: [Double](repeating: 1, count: p), timeScale: 1, revision: target.stamp.revision)
        let velocity = try ConstraintCoordinateLayout(coordinateIDs: (0..<n).map { UInt64($0 + 101) },
            dimensions: vDimensions, scales: [Double](repeating: 1, count: n), timeScale: 1, revision: target.stamp.revision)
        var linear = [Double](repeating: 0, count: p), drive = [Double](repeating: 0, count: n)
        linear[b.positions.start] = 1; linear[c.positions.start] = -1
        drive[b.velocities.start] = -4
        let retained = QuadraticConstraint(id: 12, constant: 0, linear: linear,
            hessian: [Double](repeating: 0, count: p * p), timeLinear: 0, timeQuadratic: 0,
            mixedTime: [Double](repeating: 0, count: p))
        let constraints = try QuadraticConstraintSystem(layout: positions, rows: [retained],
            minimumPosition: [Double](repeating: -100, count: p), maximumPosition: [Double](repeating: 100, count: p),
            minimumTime: 0, maximumTime: 10)
        return try makeEquation(identity: "quadratic-cold-released-target", model: target,
            constraints: constraints, velocityLayout: velocity, drive: drive)
    }

    @inline(never)
    private static func makeEquation(identity: String, model: CompiledMechanicalModel, constraints: QuadraticConstraintSystem,
        velocityLayout: ConstraintCoordinateLayout, drive: [Double]) throws -> NonlinearMechanismEquation {
        let solve = try solvePolicy(velocities: model.tree.layout.velocityCount, revision: model.stamp.revision)
        let position = try constraintPolicy(coordinates: model.tree.layout.positionCount, revision: model.stamp.revision)
        return try NonlinearMechanismEquation(identity: identity, sourceBoundModel: model, constraints: constraints,
            velocityLayout: velocityLayout, drive: drive, policy: solve,
            projection: NonlinearMechanismProjectionPolicy(position: position, maximumIterations: 32, maximumCorrection: 1),
            admission: TopologyProbeContext.admission(), maximumIdentityBytes: 131072)
    }

    @inline(never)
    static func prepare(release: SubtreeRelease, equations: NonlinearMechanismEquation) throws -> NonlinearReconciledSubtreeRelease {
        var work = try TopologyProbeContext.work()
        let service: any NonlinearSubtreeAccelerationPreparing = ReferenceNonlinearSubtreeAccelerationPreparer()
        return try service.prepare(release: release, equations: equations, work: &work)
    }

    @inline(never)
    static func continuation(_ equations: NonlinearMechanismEquation) throws -> IntegrationContinuationProvider {
        let scales = try equations.descriptor.dimensions.map { try ODEErrorScale(dimension: $0, absoluteSI: 1e-7, relative: 0) }
        let integration = try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: 0.02, minimumStep: 1e-8,
            maximumStep: 0.02, safety: 0.8, minimumFactor: 0.1, maximumFactor: 2, scales: scales,
            maximumContinuationBytes: 262144, budget: IntegrationBudget(maximumCoordinates: 32, maximumAttempts: 100,
                maximumAcceptedSteps: 100, maximumOuterArithmetic: 1_000_000,
                supplier: NumericalBudget(scalarStorage: 2_000_000, arithmeticOperations: 100_000_000, iterations: 100_000)))
        return try IntegrationContinuationProvider(descriptor: equations.descriptor, policy: integration)
    }

    @inline(never)
    static func handler(equations: NonlinearMechanismEquation, continuation: IntegrationContinuationProvider) throws -> NonlinearMechanismCheckpointHandler {
        let base = ReferenceRuntimeCheckpointHandler(contributors: continuation, revisions: ReferenceModelRevisionUpdater())
        return try NonlinearMechanismCheckpointHandler(equations: equations, continuation: continuation, base: base,
            validationBudget: NumericalBudget(scalarStorage: 2_000_000, arithmeticOperations: 100_000_000, iterations: 100_000))
    }

    static func configuration(_ continuation: IntegrationContinuationProvider) throws -> RuntimeConfiguration {
        try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "quadratic-cold-public-v1", backend: "reference-cpu", precision: "float64"),
            requiredContributors: continuation.schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 1, maximumContributorBytes: 262144,
                maximumMetadataBytes: 262144, maximumCheckpointBytes: 524288, maximumValidationWork: 1_000_000,
                maximumValidationScratchBytes: 262144, maximumObservationLeases: 1, maximumBatchStates: 2,
                maximumTransactions: 1000, maximumStepWorkUnits: 100000, maximumWorkBetweenSafePoints: 4),
            determinism: .sameBuildReplay, workload: "released-quadratic-original-force-cold-replay")
    }

    @inline(never)
    func session(physical: KinematicState? = nil) throws -> Session {
        let physical = physical ?? reconciled.physical
        let record = try continuation.initialRecord(physical: physical, equations: equations)
        return try Session(model: release.target, configuration: configuration, initialState: physical,
            contributors: [record], seed: 42, checkpoints: handler)
    }

    @inline(never)
    func record(physical: KinematicState, acceptedSteps: UInt64) throws -> RuntimeContributorState {
        var point = [Double](repeating: 0, count: equations.descriptor.dimensions.count)
        try equations.read(physical, into: &point)
        return try continuation.record(acceptedTime: physical.time, point: point, nextStep: continuation.policy.initialStep,
            acceptedSteps: acceptedSteps, normalizedError: nil)
    }

    @inline(never)
    func step(_ session: Session, to time: Double) throws -> NonlinearMechanismAdvanceResult {
        let service: any ProjectedMechanismEvolving = ProjectedNonlinearMechanismEvolution()
        return try service.advance(session, equations: equations, continuation: continuation, to: time)
    }

    @inline(never)
    func checkpoint(_ session: Session) throws -> [UInt8] { try session.checkpoint(codec: NativeRuntimeCheckpointCodec()) }

    private static func entry(_ id: EntityID, model: CompiledMechanicalModel) throws -> JointCoordinateLayout {
        guard let entry = model.tree.layout.joints.first(where: { $0.joint == id }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        return entry
    }

    @inline(never)
    private static func constraintPolicy(coordinates: Int, revision: UInt64) throws -> ConstraintSolvePolicy {
        let base = try MechanismProbeContext.policy().constraints
        return try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 16, maximumRows: 8,
            expectedLayoutRevision: revision), diagonalMetric: [Double](repeating: 1, count: coordinates), energyScale: 1,
            rankPolicy: .allowRedundancy, rankRelativeTolerance: 1e-10, originalResidualTolerance: 1e-8,
            maximumCorrection: 100, nonlinear: base.nonlinear,
            linearCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            linearTolerance: base.linearTolerance)
    }

    @inline(never)
    private static func solvePolicy(velocities: Int, revision: UInt64) throws -> MechanismSolvePolicy {
        try MechanismSolvePolicy(dynamics: TopologyProbeContext.dynamics(velocities), constraints: constraintPolicy(coordinates: velocities, revision: revision),
            maximumCoordinates: 16, maximumRows: 8, originalTolerance: 1e-8)
    }
}
