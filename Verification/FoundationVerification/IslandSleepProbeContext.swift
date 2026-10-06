import SwiftMechanics
import Synchronization

/// External public composition retaining the original physical source and measured real suppliers.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class IslandSleepProbeContext: Sendable {
    typealias Session = RuntimeSession<IslandSleepCheckpointHandler<ReferenceModelRevisionUpdater>>
    struct Calls: Sendable {
        var gearMotion = 0
        var sliderMotion = 0
        var rest = 0
        var association = 0
    }

    /// Observation wraps every required call around the unchanged physical implementation.
    final class ObservedDynamics: StationaryIslandComputing {
        private let actual: any StationaryIslandComputing = ReferenceStationaryIslandDynamics()
        private let gearID: UInt64
        private let sliderID: UInt64
        private let counts = Mutex(Calls())

        init(gearID: UInt64, sliderID: UInt64) { self.gearID = gearID; self.sliderID = sliderID }
        func snapshot() -> Calls { counts.withLock { $0 } }
        func reset() { counts.withLock { $0 = Calls() } }

        @inline(never)
        func motion(program: StationaryIslandProgram, islandID: UInt64, physical: KinematicState,
                    work: inout StationaryIslandWork) throws(StationaryIslandFailure) -> StationaryIslandMotion {
            counts.withLock {
                if islandID == gearID { $0.gearMotion += 1 }
                if islandID == sliderID { $0.sliderMotion += 1 }
            }
            return try actual.motion(program: program, islandID: islandID, physical: physical, work: &work)
        }

        @inline(never)
        func certifyRest(program: StationaryIslandProgram, islandID: UInt64, physical: KinematicState,
            thresholds: MechanismSleepPolicy, work: inout StationaryIslandWork)
            throws(StationaryIslandFailure) -> StationaryIslandRestCertificate? {
            counts.withLock { $0.rest += 1 }
            return try actual.certifyRest(program: program, islandID: islandID, physical: physical,
                thresholds: thresholds, work: &work)
        }

        @inline(never)
        func associateRest(certificate: StationaryIslandRestCertificate, program: StationaryIslandProgram,
            physical: KinematicState, work: inout StationaryIslandWork) throws(StationaryIslandFailure) -> Bool {
            counts.withLock { $0.association += 1 }
            return try actual.associateRest(certificate: certificate, program: program, physical: physical, work: &work)
        }
    }

    let original: IslandDynamicsProbeContext
    let observed: ObservedDynamics
    let initialPhysical: KinematicState
    let initialConstructionWork: StationaryIslandWork
    let gearID: UInt64
    let sliderID: UInt64
    let sleep: IslandCheckpointedMechanismSleep
    let handler: IslandSleepCheckpointHandler<ReferenceModelRevisionUpdater>
    let configuration: RuntimeConfiguration
    let operationPolicy: IslandSleepOperationPolicy
    let encodingBudget: NumericalBudget

    @inline(never)
    init(source: IslandDynamicsProbeModel? = nil, minimumRestDuration: Double = 0.15,
         maximumQueries: Int = 4) throws {
        let lower = try IslandDynamicsProbeContext(source: source)
        guard let gear = lower.program.islands.first(where: { $0.sourceCoordinateIndices.contains(lower.source.firstIndex) }),
              let slider = lower.program.islands.first(where: { $0.sourceCoordinateIndices.contains(lower.source.sliderIndex) }),
              gear.id != slider.id else { throw FoundationVerificationError.analyticCheckFailed }
        let supplier = ObservedDynamics(gearID: gear.id, sliderID: slider.id)
        original = lower; observed = supplier; gearID = gear.id; sliderID = slider.id
        let prepared = try Self.initial(lower, dynamics: supplier)
        initialPhysical = prepared.physical
        initialConstructionWork = prepared.work
        let operation = try IslandSleepOperationPolicy(maximumSupplierInvocations: 2000,
            maximumQueries: maximumQueries, maximumQuerySteps: 100, maximumRecordBytes: 131_072)
        operationPolicy = operation
        let owner = try IslandCheckpointedMechanismSleep(identity: "public-mixed-island-sleep-v1",
            program: lower.program, dynamics: supplier,
            policy: MechanismSleepContinuationPolicy(thresholds: lower.thresholds,
                minimumRestDuration: minimumRestDuration, maximumIdentityBytes: 131_072),
            integration: Self.integration(), operationPolicy: operation, participant: nil)
        sleep = owner
        handler = IslandSleepCheckpointHandler(sleep: owner, revisions: ReferenceModelRevisionUpdater())
        let provider: any IslandMechanismSleepContinuing = owner
        configuration = try Self.configuration(provider.schemas)
        encodingBudget = try NumericalBudget(scalarStorage: 1_000_000,
            arithmeticOperations: 100_000_000, iterations: 10_000)
    }

    func makeWork() -> IslandSleepWork {
        IslandSleepWork(physical: original.makeWork(), contributorEncoding: NumericalWork(budget: encodingBudget))
    }

    @inline(never)
    func session() throws -> Session {
        let provider: any IslandMechanismSleepContinuing = sleep
        let records = try [provider.initialRecord(physical: initialPhysical, acceptedSequence: 0),
            provider.initialIntegrationRecord(physical: initialPhysical, acceptedSequence: 0)]
        return try Session(model: original.source.model, configuration: configuration,
            initialState: initialPhysical, contributors: records, seed: 42, checkpoints: handler)
    }

    @inline(never)
    func step(_ session: any RuntimeSessionOperating, work: inout IslandSleepWork) throws -> IslandSleepAdvanceResult {
        let provider: any IslandMechanismSleepContinuing = sleep
        return try provider.step(session, work: &work)
    }

    @inline(never)
    func query(_ source: RuntimeAcceptedState, to time: Double, work: inout IslandSleepWork) throws -> IslandSleepTrajectoryEndpoint {
        let provider: any IslandMechanismSleepContinuing = sleep
        return try provider.query(from: source, configuration: configuration, to: time, work: &work, cancellation: nil)
    }

    @inline(never)
    func smooth(_ source: RuntimeAcceptedState, endpoint: IslandSleepTrajectoryEndpoint,
                work: inout IslandSleepWork) throws -> PreparedIslandSmoothEndpoint {
        let provider: any IslandMechanismSleepContinuing = sleep
        return try provider.prepareSmoothEndpoint(source: source, endpoint: endpoint, work: &work)
    }

    @inline(never)
    func history(_ accepted: RuntimeAcceptedState) throws -> IslandSleepHistory {
        let provider: any IslandMechanismSleepContinuing = sleep
        guard let record = accepted.checkpoint.contributors.first(where: { $0.id == provider.schema.id }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        return try provider.history(record)
    }

    @inline(never)
    func integrationHistory(_ accepted: RuntimeAcceptedState) throws -> IntegrationHistory {
        let provider: any IslandMechanismSleepContinuing = sleep
        let continuation = provider.continuation
        guard let record = accepted.checkpoint.contributors.first(where: { $0.id == continuation.schema.id }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        return try continuation.history(record)
    }

    @inline(never)
    func admit(_ checkpoint: RuntimeCheckpoint) throws -> IslandSleepAdmissionResult {
        let admitting: any IslandSleepCheckpointAdmitting = handler
        return try admitting.admitWithReport(checkpoint, model: original.source.model,
            configuration: configuration, cancellation: nil)
    }

    @inline(never)
    private static func configuration(_ schemas: [RuntimeContributorSchema]) throws -> RuntimeConfiguration {
        try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "public-island-sleep-v1",
            backend: "reference-cpu", precision: "float64"), requiredContributors: schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 3,
                maximumContributorBytes: 262_144, maximumMetadataBytes: 262_144, maximumCheckpointBytes: 1_048_576,
                maximumValidationWork: 100_000_000, maximumValidationScratchBytes: 8_000_000,
                maximumObservationLeases: 2, maximumBatchStates: 2, maximumTransactions: 1000,
                maximumStepWorkUnits: 100_000, maximumWorkBetweenSafePoints: 4),
            determinism: .sameBuildReplay, workload: "public-mixed-island-omission-and-cold-replay")
    }

    @inline(never)
    private static func integration() throws -> ExplicitIntegrationPolicy {
        let angleRate = PhysicalDimension(time: -1, angle: 1)
        let dimensions: [PhysicalDimension] = [.angle, .angle, .length, angleRate, angleRate, .velocity]
        var scales: [ODEErrorScale] = []; scales.reserveCapacity(6)
        for dimension in dimensions { scales.append(try ODEErrorScale(dimension: dimension, absoluteSI: 1e-7, relative: 0)) }
        return try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: 0.1,
            minimumStep: 1e-8, maximumStep: 0.1, safety: 0.8, minimumFactor: 0.1, maximumFactor: 2,
            scales: scales, maximumContinuationBytes: 131_072,
            budget: IntegrationBudget(maximumCoordinates: 6, maximumAttempts: 100, maximumAcceptedSteps: 100,
                maximumOuterArithmetic: 1_000_000,
                supplier: NumericalBudget(scalarStorage: 1_000_000, arithmeticOperations: 100_000_000, iterations: 10_000)))
    }

    private final class InitialPreparation: Sendable {
        let physical: KinematicState
        let work: StationaryIslandWork
        init(physical: KinematicState, work: StationaryIslandWork) { self.physical = physical; self.work = work }
    }

    @inline(never)
    private static func initial(_ lower: IslandDynamicsProbeContext,
                                dynamics: any StationaryIslandComputing) throws -> InitialPreparation {
        let physical = try lower.source.physical()
        var acceleration = [Double](repeating: 0, count: 3), work = lower.makeWork()
        for island in lower.program.islands {
            let result = try dynamics.motion(program: lower.program, islandID: island.id, physical: physical, work: &work)
            guard result.acceleration.count == island.sourceCoordinateIndices.count else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            for local in island.sourceCoordinateIndices.indices {
                acceleration[island.sourceCoordinateIndices[local]] = result.acceleration[local]
            }
        }
        return InitialPreparation(physical: try KinematicState(revision: physical.revision, time: physical.time, q: physical.q,
            v: physical.v, acceleration: acceleration), work: work)
    }
}
