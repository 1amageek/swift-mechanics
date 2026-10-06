import SwiftMechanics

/// Public source, release and restore phases retain their immutable physical owners.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class SleepTopologyProbeContext: Sendable {
    typealias Session = RuntimeSession<TopologyCheckpointHandler>
    typealias FreshSession = RuntimeSession<SleepTopologyCheckpointHandler>
    let fixture: SleepTopologyProbeModel
    let sleep: CheckpointedMechanismSleep
    let sourceEquations: AffineMechanismEquation
    let history: TopologyHistoryContributor
    let rule: TopologyReleaseRule
    let configuration: RuntimeConfiguration
    let handler: TopologyCheckpointHandler

    @inline(never)
    init(fixture: SleepTopologyProbeModel) throws {
        self.fixture = fixture
        let solve = try Self.solvePolicy(coordinates: fixture.model.tree.layout.velocityCount,
            revision: fixture.model.stamp.revision)
        let sleep = try CheckpointedMechanismSleep(identity: "sleep-topology-original-equilibrium",
            model: fixture.model, constraints: fixture.constraints, drive: fixture.drive,
            solvePolicy: solve, admission: TopologyProbeContext.admission(),
            policy: MechanismSleepContinuationPolicy(thresholds: MechanismSleepPolicy(maximumCoordinates: 16,
                kineticEnergyThreshold: 1e-8, normalizedVelocityThreshold: 1e-8),
                minimumRestDuration: 0.15, maximumIdentityBytes: 131072), integration: Self.integration())
        self.sleep = sleep
        sourceEquations = try AffineMechanismEquation(identity: sleep.descriptor.identity, model: fixture.model,
            constraints: fixture.constraints, drive: fixture.drive, policy: solve,
            admission: TopologyProbeContext.admission(), maximumIdentityBytes: 131072)
        let rule = try TopologyReleaseRule(id: 1, joint: fixture.aJoint,
            connector: EntityID(kind: .joint, key: "quadratic-cold-free-a"),
            parentAnchor: EntityID(kind: .frame, key: "quadratic-cold-free-a-parent"),
            childAnchor: EntityID(kind: .frame, key: "quadratic-cold-free-a-child"),
            subtreeRoot: fixture.a, metric: .explicitRelease)
        self.rule = rule
        let history = try TopologyHistoryContributor(model: fixture.model,
            catalog: TopologyEventCatalog(initialModel: fixture.model.stamp,
                initialTime: fixture.model.descriptor.initialState.time, initialSequence: 0,
                rules: [rule], policy: Self.historyPolicy()), policy: Self.historyPolicy())
        self.history = history
        let registry = try TopologyRuntimeContributors(providers: [sleep, history], capacity: Self.capacity())
        configuration = try Self.configuration(registry.schemas)
        let inner = SleepTopologySourceCheckpointHandler(sleep: sleep, additional: history,
            revisions: ReferenceModelRevisionUpdater())
        handler = TopologyCheckpointHandler(history: history, contributors: registry, base: inner)
    }

    @inline(never)
    func session() throws -> Session {
        let physical = fixture.model.descriptor.initialState
        return try Session(model: fixture.model, configuration: configuration, initialState: physical,
            contributors: [sleep.initialRecord(physical: physical),
                sleep.continuation.initialRecord(physical: physical, equations: sourceEquations), history.record],
            seed: 42, checkpoints: handler)
    }

    @inline(never)
    func sleepSource(_ session: Session, steps: Int = 2) throws -> RuntimeAcceptedState {
        guard steps >= 0, steps <= 100 else { throw FoundationVerificationError.analyticCheckFailed }
        for _ in 0..<steps { _ = try sleep.step(session) }
        return session.snapshot()
    }

    @inline(never)
    func release(_ source: RuntimeAcceptedState, work: inout NumericalWork,
        dynamicsWork: inout NumericalWork) throws -> SubtreeRelease {
        let service: any SubtreeReleaseBuilding = ReferenceSubtreeReleaseBuilder()
        return try service.release(model: fixture.model, state: source.physical, joint: rule.joint,
            connector: rule.connector, parentAnchor: rule.parentAnchor, childAnchor: rule.childAnchor,
            policy: TopologyProbeContext.policy(), admission: TopologyProbeContext.admission(),
            work: &work, dynamicsWork: &dynamicsWork)
    }

    @inline(never)
    func retainedConstraints(_ release: SubtreeRelease) throws -> QuadraticConstraintSystem {
        let p = release.target.tree.layout.positionCount
        let b = try Self.entry(fixture.bJoint, model: release.target)
        let c = try Self.entry(fixture.cJoint, model: release.target)
        let free = try Self.entry(release.connector, model: release.target)
        guard p <= 16, free.positions.count == 7 else { throw FoundationVerificationError.analyticCheckFailed }
        var ids = (0..<p).map { UInt64($0 + 1001) }
        var dimensions = [PhysicalDimension](repeating: .length, count: p)
        var scales = [Double](repeating: 1, count: p)
        var lower = [Double](repeating: -100, count: p), upper = [Double](repeating: 100, count: p)
        for i in 3..<7 { dimensions[free.positions.start + i] = .dimensionless }
        for (target, source) in [(b.positions.start, fixture.bPosition), (c.positions.start, fixture.cPosition)] {
            ids[target] = fixture.constraints.layout.coordinateIDs[source]
            dimensions[target] = fixture.constraints.layout.dimensions[source]
            scales[target] = fixture.constraints.layout.scales[source]
            lower[target] = fixture.constraints.minimumPosition[source]
            upper[target] = fixture.constraints.maximumPosition[source]
        }
        let layout = try ConstraintCoordinateLayout(coordinateIDs: ids, dimensions: dimensions,
            scales: scales, timeScale: fixture.constraints.layout.timeScale, revision: release.target.stamp.revision)
        var linear = [Double](repeating: 0, count: p)
        linear[b.positions.start] = 1; linear[c.positions.start] = -1
        return try QuadraticConstraintSystem(layout: layout,
            rows: [QuadraticConstraint(id: 12, constant: 0, linear: linear,
                hessian: [Double](repeating: 0, count: p * p), timeLinear: 0, timeQuadratic: 0,
                mixedTime: [Double](repeating: 0, count: p))],
            minimumPosition: lower, maximumPosition: upper,
            minimumTime: fixture.constraints.minimumTime, maximumTime: fixture.constraints.maximumTime)
    }

    @inline(never)
    func velocityLayout(_ release: SubtreeRelease) throws -> ConstraintCoordinateLayout {
        let n = release.target.tree.layout.velocityCount
        let b = try Self.entry(fixture.bJoint, model: release.target)
        let c = try Self.entry(fixture.cJoint, model: release.target)
        let free = try Self.entry(release.connector, model: release.target)
        guard n <= 16, free.velocities.count == 6 else { throw FoundationVerificationError.analyticCheckFailed }
        var ids = (0..<n).map { UInt64($0 + 2001) }
        var dimensions = [PhysicalDimension](repeating: .length, count: n)
        var scales = [Double](repeating: 1, count: n)
        for i in 3..<6 { dimensions[free.velocities.start + i] = .angle }
        for (target, source) in [(b.velocities.start, fixture.bVelocity), (c.velocities.start, fixture.cVelocity)] {
            ids[target] = fixture.constraints.layout.coordinateIDs[source]
            dimensions[target] = fixture.constraints.layout.dimensions[source]
            scales[target] = fixture.constraints.layout.scales[source]
        }
        return try ConstraintCoordinateLayout(coordinateIDs: ids, dimensions: dimensions, scales: scales,
            timeScale: fixture.constraints.layout.timeScale, revision: release.target.stamp.revision)
    }

    @inline(never)
    func equation(_ release: SubtreeRelease) throws -> NonlinearMechanismEquation {
        let velocity = try velocityLayout(release)
        var drive = [Double](repeating: 0, count: velocity.scales.count)
        drive[try Self.entry(fixture.bJoint, model: release.target).velocities.start] = fixture.drive[fixture.bVelocity]
        return try NonlinearMechanismEquation(identity: "sleep-topology-retained-coupling",
            sourceBoundModel: release.target, constraints: retainedConstraints(release), velocityLayout: velocity,
            drive: drive, policy: Self.solvePolicy(coordinates: velocity.scales.count, revision: release.target.stamp.revision),
            projection: NonlinearMechanismProjectionPolicy(position: Self.constraintPolicy(
                coordinates: release.target.tree.layout.positionCount, revision: release.target.stamp.revision),
                maximumIterations: 32, maximumCorrection: 1),
            admission: TopologyProbeContext.admission(), maximumIdentityBytes: 131072)
    }

    @inline(never)
    func retire(source: RuntimeAcceptedState, release: SubtreeRelease, equations: NonlinearMechanismEquation,
        work: inout NumericalWork) throws -> PreparedSleepTopologyRetirement {
        let owner: any MechanismSleepTopologyRetiring = sleep
        return try owner.prepareRetirement(source: source, sourceConfiguration: configuration, checkpoints: handler,
            release: release, retiredConstraintIDs: [11], targetConstraints: retainedConstraints(release),
            targetVelocityLayout: equations.velocityLayout, cancellation: nil, work: &work)
    }

    @inline(never)
    func reconcile(release: SubtreeRelease, equations: NonlinearMechanismEquation,
        work: inout NumericalWork) throws -> NonlinearReconciledSubtreeRelease {
        let service: any NonlinearSubtreeAccelerationPreparing = ReferenceNonlinearSubtreeAccelerationPreparer()
        return try service.prepare(release: release, equations: equations, work: &work)
    }

    @inline(never)
    func prepare(source: RuntimeAcceptedState, retirement: PreparedSleepTopologyRetirement,
        transition: NonlinearReconciledSubtreeRelease, equations: NonlinearMechanismEquation,
        work: inout NumericalWork) throws -> PreparedSleepTopologyPublication {
        let continuation = try QuadraticColdProbeContext.continuation(equations)
        let targetConfiguration = try targetConfiguration(source: source, retirement: retirement,
            transition: transition, continuation: continuation, work: &work)
        let service: any SleepTopologyTransitionPreparing = ReferenceSleepTopologyTransitionPreparer()
        return try service.prepare(source: source, sourceConfiguration: configuration, retirement: retirement,
            transition: transition, history: history, observation: .explicit(transition.release), ruleID: rule.id,
            dispositions: [.appendHistory, .retireSleep, .initializeGlobalIntegration(retiredID: sleep.continuation.schema.id)],
            targetConfiguration: targetConfiguration, equations: equations, continuation: continuation,
            validationBudget: Self.validationBudget(), cancellation: nil, work: &work)
    }

    @inline(never)
    func targetConfiguration(source: RuntimeAcceptedState, retirement: PreparedSleepTopologyRetirement,
        transition: NonlinearReconciledSubtreeRelease, continuation: IntegrationContinuationProvider,
        work: inout NumericalWork) throws -> RuntimeConfiguration {
        let appended = try history.appending(source: source, target: transition,
            observation: .explicit(transition.release), ruleID: rule.id)
        let wake = try SleepTopologyWakeContributor(retirement: retirement, transition: transition,
            history: appended, ruleID: rule.id, policy: Self.historyPolicy(), work: &work)
        return try Self.configuration(appended.schemas + wake.schemas + continuation.schemas)
    }

    @inline(never)
    func publish(_ prepared: PreparedSleepTopologyPublication, session: Session) throws -> RuntimeAcceptedState {
        let service: any SleepTopologyTransitionPreparing = ReferenceSleepTopologyTransitionPreparer()
        return try service.publish(prepared, session: session)
    }

    @inline(never)
    func step(_ session: any RuntimeSessionOperating, equations: NonlinearMechanismEquation,
        continuation: IntegrationContinuationProvider, to time: Double) throws -> NonlinearMechanismAdvanceResult {
        let service: any ProjectedMechanismEvolving = ProjectedNonlinearMechanismEvolution()
        return try service.advance(session, equations: equations, continuation: continuation, to: time)
    }

    @inline(never)
    func checkpoint(_ session: Session) throws -> [UInt8] { try session.checkpoint(codec: NativeRuntimeCheckpointCodec()) }

    @inline(never)
    func freshSession(_ prepared: PreparedSleepTopologyPublication,
        equations: NonlinearMechanismEquation) throws -> FreshSession {
        let target = prepared.transition.release.target, savedHistory = prepared.handler.history
        let physical = try target.makeState(prepared.transition.physical)
        let bootstrapHistory = try TopologyHistoryContributor(model: target,
            catalog: TopologyEventCatalog(initialModel: target.stamp, initialTime: physical.state.time,
                initialSequence: 0, rules: savedHistory.catalog.rules, policy: savedHistory.policy), policy: savedHistory.policy)
        var work = try TopologyProbeContext.work()
        let bootstrapWake = try SleepTopologyWakeContributor(bootstrapFor: prepared.wake, physical: physical, work: &work)
        let registry = try TopologyRuntimeContributors(providers: [bootstrapHistory, bootstrapWake, prepared.continuation],
            capacity: prepared.configuration.capacity)
        let base = try TopologyCheckpointHandler(history: savedHistory, contributors: prepared.handler.contributors,
            bootstrap: bootstrapHistory, physical: physical, bootstrapContributors: registry)
        let handler = try SleepTopologyCheckpointHandler(wake: prepared.wake, history: savedHistory,
            equations: equations, continuation: prepared.continuation, base: base, validationBudget: Self.validationBudget(),
            bootstrapWake: bootstrapWake, bootstrapHistory: bootstrapHistory, bootstrapPhysical: physical)
        return try FreshSession(model: target, configuration: prepared.configuration, initialState: physical.state,
            contributors: [bootstrapHistory.record, bootstrapWake.record,
                prepared.continuation.initialRecord(physical: physical.state, equations: equations)], seed: 42, checkpoints: handler)
    }

    private static func entry(_ id: EntityID, model: CompiledMechanicalModel) throws -> JointCoordinateLayout {
        guard let entry = model.tree.layout.joints.first(where: { $0.joint == id }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        return entry
    }

    static func capacity() throws -> RuntimeCapacity {
        try RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 4, maximumContributorBytes: 262144,
            maximumMetadataBytes: 262144, maximumCheckpointBytes: 1048576, maximumValidationWork: 20000000,
            maximumValidationScratchBytes: 8000000, maximumObservationLeases: 2, maximumBatchStates: 2,
            maximumTransactions: 1000, maximumStepWorkUnits: 100000, maximumWorkBetweenSafePoints: 4)
    }

    static func configuration(_ schemas: [RuntimeContributorSchema]) throws -> RuntimeConfiguration {
        try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "sleep-topology-public-v1",
            backend: "reference-cpu", precision: "float64"), requiredContributors: schemas,
            capacity: capacity(), determinism: .sameBuildReplay, workload: "sleep-retirement-retained-coupling")
    }

    static func validationBudget() throws -> NumericalBudget {
        try NumericalBudget(scalarStorage: 2_000_000, arithmeticOperations: 100_000_000, iterations: 100_000)
    }

    static func historyPolicy() throws -> TopologyContinuationPolicy {
        try TopologyContinuationPolicy(maximumEvents: 2, maximumBytes: 262144,
            maximumMetadataBytes: 262144, maximumWork: 2_000_000)
    }

    private static func integration() throws -> ExplicitIntegrationPolicy {
        let scales = try [PhysicalDimension](repeating: .length, count: 3).map {
            try ODEErrorScale(dimension: $0, absoluteSI: 1e-7, relative: 0)
        } + [PhysicalDimension](repeating: .velocity, count: 3).map {
            try ODEErrorScale(dimension: $0, absoluteSI: 1e-7, relative: 0)
        }
        return try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: 0.1, minimumStep: 1e-8,
            maximumStep: 0.1, safety: 0.8, minimumFactor: 0.1, maximumFactor: 2, scales: scales,
            maximumContinuationBytes: 262144, budget: IntegrationBudget(maximumCoordinates: 32, maximumAttempts: 100,
                maximumAcceptedSteps: 100, maximumOuterArithmetic: 1_000_000, supplier: validationBudget()))
    }

    @inline(never)
    private static func constraintPolicy(coordinates: Int, revision: UInt64) throws -> ConstraintSolvePolicy {
        let original = try MechanismProbeContext.policy().constraints
        return try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 16, maximumRows: 8,
            expectedLayoutRevision: revision), diagonalMetric: [Double](repeating: 1, count: coordinates), energyScale: 1,
            rankPolicy: .allowRedundancy, rankRelativeTolerance: 1e-10, originalResidualTolerance: 1e-8,
            maximumCorrection: 100, nonlinear: original.nonlinear,
            linearCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            linearTolerance: original.linearTolerance)
    }

    @inline(never)
    private static func solvePolicy(coordinates: Int, revision: UInt64) throws -> MechanismSolvePolicy {
        try MechanismSolvePolicy(dynamics: TopologyProbeContext.dynamics(coordinates),
            constraints: constraintPolicy(coordinates: coordinates, revision: revision),
            maximumCoordinates: 16, maximumRows: 8, originalTolerance: 1e-8)
    }
}
