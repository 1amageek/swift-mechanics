import SwiftMechanics
import Synchronization

/// Independent caller settings and owners for the bounded accepted-time sensor stream.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class SensorPipelineProbeContext: Sendable {
    typealias Contributors = SensorPipelineContributorHandler<IntegrationContinuationProvider>
    typealias Checkpoints = ReferenceRuntimeCheckpointHandler<Contributors, ReferenceModelRevisionUpdater>
    typealias Session = SensorPipelineSession<Checkpoints>
    let fixture: SensorPipelineProbeModel
    let definition: SensorPipelineDefinition
    let continuation: IntegrationContinuationProvider
    let configuration: RuntimeConfiguration
    let session: Session

    @inline(never)
    init(readyRows: Int = 32,
         overflow: SensorPipelineDefinition.ReadyOverflow = .refuseOverflow,
         sampling: SensorPipelineDefinition.Sampling = .endpointOnly,
         noiseHalfWidth: Double = 0.05, rootSeed: UInt64 = 123) throws {
        let fixture = try SensorPipelineProbeModel()
        self.fixture = fixture
        let definition = try Self.definition(fixture: fixture, readyRows: readyRows,
            overflow: overflow, sampling: sampling, noiseHalfWidth: noiseHalfWidth, rootSeed: rootSeed)
        self.definition = definition
        let continuation = try IntegrationContinuationProvider(descriptor: fixture.equation.descriptor,
            policy: Self.integrationPolicy())
        self.continuation = continuation
        let capacity = try Self.capacity()
        let contributors = try Contributors(original: continuation, definition: definition, capacity: capacity)
        let configuration = try Self.configuration(contributors.schemas, capacity: capacity)
        self.configuration = configuration
        session = try Self.session(fixture: fixture, definition: definition,
            continuation: continuation, contributors: contributors, configuration: configuration)
    }

    @inline(never)
    private static func session(fixture: SensorPipelineProbeModel, definition: SensorPipelineDefinition,
        continuation: IntegrationContinuationProvider, contributors: Contributors,
        configuration: RuntimeConfiguration) throws -> Session {
        let handler = Checkpoints(contributors: contributors, revisions: ReferenceModelRevisionUpdater())
        let initial = try continuation.initialRecord(physical: fixture.model.descriptor.initialState,
            equations: fixture.equation)
        return try Session(model: fixture.model, configuration: configuration,
            initialState: fixture.model.descriptor.initialState, contributors: [initial], seed: 7,
            definition: definition, checkpoints: handler)
    }

    @inline(never)
    private static func capacity() throws -> RuntimeCapacity {
        try RuntimeCapacity(maximumPhysicalScalars: 3, maximumContributors: 2,
            maximumContributorBytes: 67584, maximumMetadataBytes: 16384, maximumCheckpointBytes: 98304,
            maximumValidationWork: 10000000, maximumValidationScratchBytes: 655360,
            maximumObservationLeases: 2, maximumBatchStates: 32, maximumTransactions: 128,
            maximumStepWorkUnits: 1000, maximumWorkBetweenSafePoints: 4)
    }

    @inline(never)
    private static func configuration(_ schemas: [RuntimeContributorSchema], capacity: RuntimeCapacity) throws -> RuntimeConfiguration {
        try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "sensor-public-swift-6.4.0",
            backend: "reference-cpu", precision: "float64"), requiredContributors: schemas, capacity: capacity,
            determinism: .sameBuildReplay, workload: "accepted-rotor-sensor-delivery")
    }

    @inline(never)
    func step() throws(IntegrationFailure) {
        let integrator: any ExplicitIntegrating = ReferenceExplicitIntegrator()
        _ = try integrator.step(session, model: fixture.model, equations: fixture.equation, continuation: continuation)
    }

    @inline(never)
    func checkpoint() throws(RuntimeFailure) -> [UInt8] {
        let pipeline: any SensorPipelineOperating = session
        return try pipeline.checkpoint(codec: NativeRuntimeCheckpointCodec())
    }

    @inline(never)
    func batch(after cursor: UInt64 = 0) throws(SensorPipelineFailure) -> SensorBatch {
        let recorder = BatchRecorder()
        let request = try SensorBatchReadRequest(schema: definition.schemaID, version: definition.version,
            world: definition.world, model: fixture.model.stamp, after: cursor, maximumRows: 32, maximumScalars: 32)
        let pipeline: any SensorPipelineOperating = session
        try pipeline.readBatch(request) { lease throws(SensorPipelineFailure) in
            try lease.read { batch throws(SensorPipelineFailure) in recorder.record(batch) }
        }
        guard let batch = recorder.batch() else { throw .invalidLease }
        return batch
    }

    /// Re-encodes the genuine original integration history, leaving the sensor source unchanged.
    @inline(never)
    func checkpointWithChangedPhysical() throws -> [UInt8] {
        let checkpoint = session.snapshot().checkpoint
        let physical = try KinematicState(revision: checkpoint.physical.revision, time: checkpoint.physical.time,
            q: [checkpoint.physical.q[0] + 0.125], v: checkpoint.physical.v, acceleration: checkpoint.physical.acceleration)
        guard let integrationRecord = checkpoint.contributors.first(where: { $0.id == continuation.schema.id }) else {
            throw RuntimeFailure(.missingContributor, message: "Public integration record missing.")
        }
        let original = try continuation.history(integrationRecord)
        let replacement = try continuation.record(acceptedTime: original.acceptedTime,
            point: [physical.q[0], physical.v[0]], nextStep: original.nextStep,
            acceptedSteps: original.acceptedSteps, normalizedError: original.normalizedError)
        let records = checkpoint.contributors.map { $0.id == replacement.id ? replacement : $0 }
        let changed = try RuntimeCheckpoint(model: checkpoint.model, continuation: checkpoint.continuation,
            physical: physical, contributors: records, random: checkpoint.random, acceptedSteps: checkpoint.acceptedSteps)
        return try NativeRuntimeCheckpointCodec().encode(changed, capacity: configuration.capacity)
    }

    @inline(never)
    private static func definition(fixture: SensorPipelineProbeModel, readyRows: Int,
        overflow: SensorPipelineDefinition.ReadyOverflow, sampling: SensorPipelineDefinition.Sampling,
        noiseHalfWidth: Double, rootSeed: UInt64) throws -> SensorPipelineDefinition {
        let angularRate = PhysicalDimension(time: -1, angle: 1)
        let angularAcceleration = PhysicalDimension(time: -2, angle: 1)
        let channels = [
            try SensorChannel(id: "position-uniform", streamKey: 11,
                source: .encoder(joint: fixture.joint, quantity: .position, axis: 0), dimension: .angle,
                processing: SensorProcessing(bias: 0.1, noiseHalfWidth: noiseHalfWidth, delaySeconds: 0.1875)),
            try SensorChannel(id: "rate-quantized-clipped", streamKey: 12,
                source: .encoder(joint: fixture.joint, quantity: .velocity, axis: 0), dimension: angularRate,
                processing: SensorProcessing(bias: 1, quantizationStep: 0.25,
                    saturationLower: 0, saturationUpper: 2, delaySeconds: 0.1875)),
            try SensorChannel(id: "mounted-specific-force", streamKey: 13,
                source: .imu(mount: fixture.mount, quantity: .specificForce, axis: 0, gravityWorld: .zero),
                dimension: .acceleration, processing: SensorProcessing(delaySeconds: 0.1875)),
            try SensorChannel(id: "mounted-gyro", streamKey: 14,
                source: .imu(mount: fixture.mount, quantity: .angularVelocity, axis: 2, gravityWorld: .zero),
                dimension: angularRate, processing: SensorProcessing(delaySeconds: 0.1875)),
            try SensorChannel(id: "explicit-dropout", streamKey: 15,
                source: .encoder(joint: fixture.joint, quantity: .acceleration, axis: 0),
                dimension: angularAcceleration,
                processing: SensorProcessing(dropoutProbability: 1, delaySeconds: 0.1875))
        ]
        return try SensorPipelineDefinition(schemaID: "sensor-pipeline-public.v1", world: "sensor-public-world",
            rootSeed: rootSeed, worldKey: 7, initialTimeSeconds: 0, originSeconds: 0, periodSeconds: 0.125,
            emitInitial: false, sampling: sampling, readyOverflow: overflow, channels: channels,
            bounds: SensorPipelineBounds(maximumChannels: 5, maximumMetadataBytes: 8192,
                maximumTicksPerStep: 4, maximumTick: 32, maximumDraws: 128,
                maximumPendingRows: 20, maximumReadyRows: readyRows, maximumBatchRows: 32,
                maximumContributorBytes: 65536, maximumDelaySeconds: 1,
                rawBudget: NumericalBudget(scalarStorage: 10000, arithmeticOperations: 1000000, iterations: 10000)),
            rawPolicy: ObservationPolicy(maximumBodies: 2, maximumCoordinates: 2,
                maximumReactionRows: 0, maximumMetadataBytes: 4096))
    }

    @inline(never)
    private static func integrationPolicy() throws -> ExplicitIntegrationPolicy {
        try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: 0.125,
            minimumStep: 0.125, maximumStep: 0.125, safety: 0.8, minimumFactor: 0.1, maximumFactor: 2,
            scales: [ODEErrorScale(dimension: .angle, absoluteSI: 1e-9, relative: 0),
                ODEErrorScale(dimension: PhysicalDimension(time: -1, angle: 1), absoluteSI: 1e-9, relative: 0)],
            maximumContinuationBytes: 2048,
            budget: IntegrationBudget(maximumCoordinates: 2, maximumAttempts: 32, maximumAcceptedSteps: 32,
                maximumOuterArithmetic: 1000000,
                supplier: NumericalBudget(scalarStorage: 1000, arithmeticOperations: 100000, iterations: 1000)))
    }

    /// The independent public RNG specification, rather than an internal sensor helper.
    static func uniform(streamKey: UInt64, draw: UInt64, rootSeed: UInt64 = 123) -> Double {
        let world = RuntimeRandomState.worldSeed(rootSeed: rootSeed, index: 7)
        let channel = RuntimeRandomState.worldSeed(rootSeed: world, index: streamKey)
        let bits = RuntimeRandomState.worldSeed(rootSeed: channel, index: draw)
        return (Double(bits >> 40) + 0.5) / 16777216
    }

    final class BatchRecorder: Sendable {
        private let storage = Mutex<SensorBatch?>(nil)
        private let retainedLease = Mutex<SensorBatchLease?>(nil)
        func record(_ batch: SensorBatch) {
            let retired = storage.withLock { value in
                let previous = value
                value = batch
                return previous
            }
            withExtendedLifetime(retired) {}
        }
        func batch() -> SensorBatch? { storage.withLock { $0 } }
        func retain(_ lease: SensorBatchLease) {
            let retired = retainedLease.withLock { value in
                let previous = value
                value = lease
                return previous
            }
            withExtendedLifetime(retired) {}
        }
        func lease() -> SensorBatchLease? { retainedLease.withLock { $0 } }
    }
}
