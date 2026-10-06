import SwiftMechanics

/// Original source, zero-load island law and original contact inputs owned by immutable references.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class ConstrainedSleepProbeContext: Sendable {
    typealias Handler = IslandSleepCheckpointHandler<ReferenceModelRevisionUpdater>
    typealias Session = RuntimeSession<Handler>
    let source: IslandDynamicsProbeModel
    let cancellation: HybridCancellation
    let program: StationaryIslandProgram
    let constructionWork: StationaryIslandWork
    let impactTemplate: ConstrainedImpactProbeContext
    let initial: KinematicState
    let integration: ExplicitIntegrationPolicy
    let sleepPolicy: MechanismSleepContinuationPolicy
    let evolutionPolicy: HybridEvolutionPolicy
    let queryPolicy: CollisionQueryPolicy
    let numericalBudget: NumericalBudget
    let loadBudget: LoadBudget

    @inline(never) init(restitution: Double = 1) throws {
        let source = try IslandDynamicsProbeModel()
        cancellation = HybridCancellation()
        let numerical = try NumericalBudget(scalarStorage: 1_000_000, arithmeticOperations: 100_000_000, iterations: 100_000)
        let loads = try LoadBudget(maximumWork: 1_000_000, maximumScalars: 100_000)
        var work = StationaryIslandWork(numerical: NumericalWork(budget: numerical), loads: LoadWork(budget: loads))
        let preparing: any StationaryIslandPreparing = ReferenceStationaryIslandPreparer()
        let program = try preparing.prepare(source: source.model, constraints: source.constraints,
            drive: source.drive(first: 0, second: 0, slider: 0), policy: IslandDynamicsProbeContext.makePolicy(), work: &work)
        self.source = source
        self.program = program
        constructionWork = work
        numericalBudget = numerical
        loadBudget = loads
        impactTemplate = try ConstrainedImpactProbeContext(restitution: restitution)
        // Actual root center starts .75 above the gear sphere center; radii sum to .5.
        // Zero original force and C velocity -1 therefore give contact at t=.25.
        initial = try source.physical(sliderPosition: 0.75, sliderVelocity: -1, time: 0)
        integration = try Self.integrationPolicy()
        sleepPolicy = try MechanismSleepContinuationPolicy(
            thresholds: MechanismSleepPolicy(maximumCoordinates: 3, kineticEnergyThreshold: 1e-12, normalizedVelocityThreshold: 1e-12),
            minimumRestDuration: 0.1, maximumIdentityBytes: 500_000)
        evolutionPolicy = try HybridEvolutionPolicy(maximumEvents: 4, maximumQueries: 128, maximumRootIterations: 64,
            maximumCatalogEvents: 1, maximumContinuationBytes: 65536, timeTolerance: 1e-10, minimumEventSpacing: 1e-6)
        queryPolicy = try CollisionQueryPolicy(absoluteLengthTolerance: 1e-10, relativeLengthTolerance: 1e-10,
            referenceLength: 1, maximumApproximationError: 0)
    }

    var firstCollider: CollisionProxy { impactTemplate.input.collision.proxies[0] }
    var secondCollider: CollisionProxy { impactTemplate.input.collision.proxies[1] }
    var firstColliderToBody: RigidTransform { impactTemplate.input.contacts[0].firstColliderToBody }
    var secondColliderToBody: RigidTransform { impactTemplate.input.contacts[0].secondColliderToBody }
    var law: ContactLawPair { impactTemplate.input.contacts[0].law }

    func stationaryWork() -> StationaryIslandWork {
        StationaryIslandWork(numerical: NumericalWork(budget: numericalBudget), loads: LoadWork(budget: loadBudget))
    }

    @inline(never) func makeSleep(participant: (any IslandEndpointContributing)? = nil) throws -> IslandCheckpointedMechanismSleep {
        try IslandCheckpointedMechanismSleep(identity: "constrained-sleep-public-ode", program: program,
            policy: sleepPolicy, integration: integration,
            operationPolicy: IslandSleepOperationPolicy(maximumSupplierInvocations: 100_000,
                maximumQueries: 128, maximumQuerySteps: 100, maximumRecordBytes: 1_000_000), participant: participant)
    }

    func sleepWork() -> IslandSleepWork {
        IslandSleepWork(physical: stationaryWork(), contributorEncoding: NumericalWork(budget: numericalBudget))
    }

    @inline(never) func configuration(_ owner: IslandCheckpointedMechanismSleep) throws -> RuntimeConfiguration {
        try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "constrained-sleep-public-v1",
            backend: "referenceCPU", precision: "float64"), requiredContributors: owner.schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 20, maximumContributors: 3,
                maximumContributorBytes: 1_000_000, maximumMetadataBytes: 1_000_000,
                maximumCheckpointBytes: 3_000_000, maximumValidationWork: 100_000_000,
                maximumValidationScratchBytes: 10_000_000, maximumObservationLeases: 2, maximumBatchStates: 2,
                maximumTransactions: 1000, maximumStepWorkUnits: 1_000_000, maximumWorkBetweenSafePoints: 100),
            determinism: .sameBuildReplay, workload: "directed-geared-striker-sleep-impact")
    }

    @inline(never) func session(_ owner: IslandCheckpointedMechanismSleep,
                                eventRecord: RuntimeContributorState) throws -> Session {
        let configuration = try self.configuration(owner)
        let records = try [owner.initialRecord(physical: initial, acceptedSequence: 0),
            owner.initialIntegrationRecord(physical: initial, acceptedSequence: 0), eventRecord]
        return try Session(model: source.model, configuration: configuration, initialState: initial,
            contributors: records, seed: 42, checkpoints: Handler(sleep: owner, revisions: ReferenceModelRevisionUpdater()))
    }

    @inline(never) func history(_ owner: IslandCheckpointedMechanismSleep,
                                accepted: RuntimeAcceptedState) throws -> IslandSleepHistory {
        guard let record = accepted.checkpoint.contributors.first(where: { $0.id == owner.schema.id }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let observing: any IslandMechanismSleepContinuing = owner
        return try observing.history(record)
    }

    @inline(never) func evolutionWork() throws -> ConstrainedSleepEvolutionWork {
        ConstrainedSleepEvolutionWork(numerical: NumericalWork(budget: numericalBudget),
            collision: CollisionWork(budget: try CollisionBudget(scalarStorage: 100_000, operations: 100_000_000,
                iterations: 100_000, records: 1000)),
            contact: ContactWork(budget: try ContactBudget(operations: 1_000_000, scalarStorage: 100_000, records: 100)),
            loads: LoadWork(budget: loadBudget), islands: sleepWork())
    }

    /// Construction terminates before any nested Runtime/Integration/physical query begins.
    final class Operation: Sendable {
        let context: ConstrainedSleepProbeContext
        let environment: GearedStrikerEventEnvironment
        let events: ConstrainedSleepEventContinuation
        let sleep: IslandCheckpointedMechanismSleep
        let configuration: RuntimeConfiguration
        let checkpoints: Handler
        let evolution: any ConstrainedSleepEvolving
        let session: Session

        @inline(never) init(restitution: Double = 1) throws {
            let context = try ConstrainedSleepProbeContext(restitution: restitution)
            let environment = try GearedStrikerEventEnvironment(program: context.program,
                first: context.firstCollider, second: context.secondCollider,
                firstColliderToBody: context.firstColliderToBody, secondColliderToBody: context.secondColliderToBody,
                law: context.law, eventID: 41, geometryRevision: 1, queryPolicy: context.queryPolicy,
                evolutionPolicy: context.evolutionPolicy, impactPolicy: context.impactTemplate.policy)
            let events = try ConstrainedSleepEventContinuation(environment: environment, policy: context.evolutionPolicy)
            let sleep = try context.makeSleep(participant: events)
            let configuration = try context.configuration(sleep)
            let handler = Handler(sleep: sleep, revisions: ReferenceModelRevisionUpdater())
            let evolution: any ConstrainedSleepEvolving = try ReferenceConstrainedSleepEvolution(sleep: sleep,
                environment: environment, continuation: events, configuration: configuration, checkpoints: handler)
            let session = try context.session(sleep, eventRecord: events.initialRecord(physical: context.initial, acceptedSequence: 0))
            self.context = context; self.environment = environment; self.events = events; self.sleep = sleep
            self.configuration = configuration; checkpoints = handler; self.evolution = evolution; self.session = session
        }

        @inline(never) func step() throws -> AcceptedEndpoint {
            var work = context.sleepWork()
            let advancing: any IslandMechanismSleepContinuing = sleep
            let result = try advancing.step(session, work: &work)
            return AcceptedEndpoint(result.integration.accepted)
        }

        @inline(never) func advance(through time: Double) throws -> EventEndpoint {
            let result = try evolution.advanceToNextImpact(session, through: time,
                work: context.evolutionWork(), cancellation: context.cancellation)
            return EventEndpoint(result)
        }

        @inline(never) func checkpoint() throws -> [UInt8] {
            let operating: any RuntimeSessionOperating = session
            let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
            return try operating.checkpoint(codec: codec)
        }

        @inline(never) func restart(_ bytes: [UInt8]) throws -> AcceptedEndpoint {
            let operating: any RuntimeSessionOperating = session
            let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
            return AcceptedEndpoint(try operating.restart(bytes, codec: codec))
        }

        @inline(never) func admit(_ checkpoint: RuntimeCheckpoint) throws -> IslandSleepAdmissionResult {
            let admitting: any IslandSleepCheckpointAdmitting = checkpoints
            return try admitting.admitWithReport(checkpoint, model: context.source.model,
                configuration: configuration, cancellation: nil)
        }

        @inline(never) func eventHistory(_ accepted: RuntimeAcceptedState) throws -> ConstrainedSleepEventHistory {
            guard let record = accepted.checkpoint.contributors.first(where: { $0.id == events.schema.id }) else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            return try events.history(record)
        }
    }

    /// Accepted rich values live in reference owners across subsequent physical callbacks.
    final class AcceptedEndpoint: Sendable {
        let accepted: RuntimeAcceptedState
        init(_ accepted: RuntimeAcceptedState) { self.accepted = accepted }
    }
    final class EventEndpoint: Sendable {
        let accepted: RuntimeAcceptedState
        let impact: ConstrainedNormalImpulseResult?
        let work: ConstrainedSleepEvolutionWork
        init(_ result: ConstrainedSleepEvolutionResult) {
            accepted = result.accepted; impact = result.impact; work = result.work
        }
    }

    @inline(never) private static func integrationPolicy() throws -> ExplicitIntegrationPolicy {
        var scales: [ODEErrorScale] = []
        for dimension in [PhysicalDimension.angle, .angle, .length] {
            scales.append(try ODEErrorScale(dimension: dimension, absoluteSI: 1e-10, relative: 1e-10))
        }
        for dimension in [PhysicalDimension(time: -1, angle: 1), PhysicalDimension(time: -1, angle: 1), .velocity] {
            scales.append(try ODEErrorScale(dimension: dimension, absoluteSI: 1e-10, relative: 1e-10))
        }
        return try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: 0.1, minimumStep: 1e-10, maximumStep: 0.1,
            safety: 0.8, minimumFactor: 0.1, maximumFactor: 2, scales: scales, maximumContinuationBytes: 1_000_000,
            budget: IntegrationBudget(maximumCoordinates: 6, maximumAttempts: 100, maximumAcceptedSteps: 100,
                maximumOuterArithmetic: 1_000_000,
                supplier: NumericalBudget(scalarStorage: 1_000_000, arithmeticOperations: 100_000_000, iterations: 100_000)))
    }
}
