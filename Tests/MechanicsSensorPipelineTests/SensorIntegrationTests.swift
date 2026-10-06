import SwiftMechanics
import Synchronization
import Testing
import Foundation

@Suite(.timeLimit(.minutes(1)))
struct SensorIntegrationTests {
    @Test(arguments: [false, true]) func originalIntegratorOnlyIssuesAcceptedTicks(_ adaptive: Bool) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let model = try SensorPipelineFixtures.model(), equation = try SensorHingeEquation(model: model, oscillatory: adaptive)
        let policy = try ExplicitIntegrationPolicy(method: adaptive ? .heunEuler : .classicalRK4, initialStep: adaptive ? 0.5 : 0.125,
            minimumStep: 1e-8, maximumStep: 1, safety: 0.8, minimumFactor: 0.1, maximumFactor: 2,
            scales: [ODEErrorScale(dimension: .angle, absoluteSI: 1e-4, relative: 0), ODEErrorScale(dimension: PhysicalDimension(time: -1, angle: 1), absoluteSI: 1e-4, relative: 0)],
            maximumContinuationBytes: 2048,
            budget: IntegrationBudget(maximumCoordinates: 2, maximumAttempts: 1000, maximumAcceptedSteps: 1000, maximumOuterArithmetic: 1000000,
                supplier: NumericalBudget(scalarStorage: 128, arithmeticOperations: 1000000, iterations: 1000)))
        let continuation = try IntegrationContinuationProvider(descriptor: equation.descriptor, policy: policy)
        let definition = try SensorPipelineFixtures.definition(sampling: adaptive ? .previousAcceptedHold : .endpointOnly)
        let capacity = try SensorPipelineFixtures.capacity()
        let registry = try SensorPipelineContributorHandler(original: continuation, definition: definition, capacity: capacity)
        let base = ReferenceRuntimeCheckpointHandler(contributors: registry, revisions: ReferenceModelRevisionUpdater())
        let config = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "sensor-integrator-v1", backend: "reference-cpu", precision: "float64"),
            requiredContributors: registry.schemas, capacity: capacity, determinism: .sameBuildReplay, workload: "sensor-integrator")
        let initial = try KinematicState(revision: 1, time: 0, q: [0], v: [2], acceleration: [adaptive ? 0 : 2])
        let session = try SensorPipelineSession(model: model, configuration: config, initialState: initial,
            contributors: [continuation.initialRecord(physical: initial, equations: equation)], seed: 42, definition: definition, checkpoints: base)
        defer { session.shutdown() }
        let result = try ReferenceExplicitIntegrator().advance(session, model: model, equations: equation, continuation: continuation, to: 0.5)
        #expect(result.reachedRequestedTime)
        let expected = adaptive ? 2*sin(0.5) : 1.25
        #expect(abs(result.accepted.physical.state.q[0] - expected) < (adaptive ? 5e-4 : 1e-12))
        #expect(adaptive ? result.rejectedTrials > 0 : result.rejectedTrials == 0)
        let rows = Mutex<[SensorRecord]>([])
        let request = try SensorBatchReadRequest(schema: definition.schemaID, version: 1, world: definition.world, model: model.stamp,
            after: 0, maximumRows: 32, maximumScalars: 32)
        try session.readBatch(request) { (lease: SensorBatchLease) throws(SensorPipelineFailure) in try lease.read { (batch: SensorBatch) throws(SensorPipelineFailure) in rows.withLock { $0 = batch.records } } }
        #expect(rows.withLock { $0.map { $0.sampleTime } } == [0.125, 0.25, 0.375, 0.5])
        #expect(rows.withLock { $0.map { $0.tick } } == [1, 2, 3, 4])
        #expect(session.snapshot().checkpoint.random.draws == 0)
        if adaptive { #expect(session.profile().rejectedTransactions > 0) }
    }
}
