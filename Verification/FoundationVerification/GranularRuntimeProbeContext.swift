import SwiftMechanics

/// Owns freshly prepared granular and Runtime owners; observations remain public journal decodes.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class GranularRuntimeProbeContext: Sendable {
    typealias Handler = GranularRuntimeCheckpointHandler<ReferenceModelRevisionUpdater>
    typealias Session = RuntimeSession<Handler>
    let fixture: GranularRuntimeProbeSource
    let journal: GranularRuntimeJournal
    let operation: ReferenceGranularTrialOperator
    let handler: Handler
    let configuration: RuntimeConfiguration
    let session: Session

    @inline(never)
    init(particleMass: Double = 1, seed: UInt64 = 123) throws {
        let fixture = try GranularRuntimeProbeSource(particleMass: particleMass, seed: seed)
        self.fixture = fixture
        let journal = GranularRuntimeJournal(source: fixture.source)
        self.journal = journal
        operation = ReferenceGranularTrialOperator(journal: journal)
        let handler = GranularRuntimeCheckpointHandler(journal: journal, revisions: ReferenceModelRevisionUpdater())
        self.handler = handler
        let configuration = try Self.configuration(journal)
        self.configuration = configuration
        session = try Self.makeSession(fixture: fixture, journal: journal, handler: handler, configuration: configuration)
    }

    @inline(never)
    private static func makeSession(fixture: GranularRuntimeProbeSource, journal: GranularRuntimeJournal,
        handler: Handler, configuration: RuntimeConfiguration) throws -> Session {
        var work = try GranularRuntimeProbeSource.work(physics: fixture.physicsBudget)
        let continuation = try journal.initial(work: &work)
        let record = try journal.encode(continuation, work: &work)
        return try Session(model: fixture.carrier, configuration: configuration,
            initialState: fixture.carrier.descriptor.initialState, contributors: [record],
            seed: fixture.initial.random.seed, checkpoints: handler)
    }

    @inline(never)
    private static func configuration(_ journal: GranularRuntimeJournal) throws -> RuntimeConfiguration {
        try RuntimeConfiguration(
            continuation: RuntimeContinuationIdentity(build: "granular-public-swift-6.4.0", backend: "reference-cpu", precision: "float64"),
            requiredContributors: [journal.schema],
            capacity: RuntimeCapacity(maximumPhysicalScalars: 0, maximumContributors: 1,
                maximumContributorBytes: 16384, maximumMetadataBytes: 16384, maximumCheckpointBytes: 32768,
                maximumValidationWork: 1000000, maximumValidationScratchBytes: 400000,
                maximumObservationLeases: 1, maximumBatchStates: 1, maximumTransactions: 100,
                maximumStepWorkUnits: 4, maximumWorkBetweenSafePoints: 1),
            determinism: .sameBuildReplay, workload: "granular-accepted-journal-cold-replay")
    }

    @inline(never)
    func work() throws -> GranularRuntimeWork { try GranularRuntimeProbeSource.work(physics: fixture.physicsBudget) }

    @inline(never)
    func checkpoint() throws -> [UInt8] { try session.checkpoint(codec: NativeRuntimeCheckpointCodec()) }
}
