import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct HybridProbeContext: Sendable {
    typealias Contributors = HybridContributors<IntegrationContinuationProvider>
    typealias Handler = ReferenceRuntimeCheckpointHandler<Contributors, ReferenceModelRevisionUpdater>
    typealias Session = RuntimeSession<Handler>
    let first: Session
    let second: Session
    let evolution: ReferenceHybridEvolution
    let history: HybridContinuationProvider
    let cancellation: HybridCancellation

    @inline(never) init() throws {
        let model = try HybridProbeModel.compile(), cancellation = HybridCancellation()
        let equation = try PrismaticBallisticEquation(model: model, accelerationMetersPerSecondSquared: -10, cancellation: cancellation, maximumIdentityBytes: 256)
        let integration = try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: 0.1, minimumStep: 1e-10, maximumStep: 0.1, safety: 0.8,
            minimumFactor: 0.1, maximumFactor: 2, scales: [ODEErrorScale(dimension: .length, absoluteSI: 1e-10, relative: 0),
                ODEErrorScale(dimension: PhysicalDimension(length: 1, time: -1), absoluteSI: 1e-10, relative: 0)], maximumContinuationBytes: 2048,
            budget: IntegrationBudget(maximumCoordinates: 2, maximumAttempts: 100, maximumAcceptedSteps: 100, maximumOuterArithmetic: 100_000,
                supplier: NumericalBudget(scalarStorage: 100, arithmeticOperations: 10_000, iterations: 1000)))
        let smooth = try IntegrationContinuationProvider(descriptor: equation.descriptor, policy: integration)
        let policy = try HybridEvolutionPolicy(maximumEvents: 10, maximumQueries: 500, maximumRootIterations: 64, maximumCatalogEvents: 4,
            maximumContinuationBytes: 4096, timeTolerance: 1e-9, minimumEventSpacing: 1e-6)
        let impact = try HybridPolicy(maximumContacts: 4, maximumColliders: 8, maximumBodies: 4, maximumVelocities: 4, maximumIdentifierBytes: 256,
            lengthTolerance: 1e-7, normalTolerance: 1e-10, speedTolerance: 1e-8, independenceTolerance: 1e-10, impulseScales: [1],
            momentumAbsolute: 1e-9, momentumRelative: 1e-10, energyAbsolute: 1e-8, energyRelative: 1e-10)
        let sphere = try HybridProbeModel.proxy("sphere", body: model.tree.bodies[1].id, shape: .sphere(radius: 0.5), pose: model.initialSnapshot.bodies[1].motion.pose, frame: model.tree.worldFrame)
        let plane = try HybridProbeModel.proxy("plane", body: model.tree.bodies[0].id, shape: .halfSpace, pose: .identity, frame: model.tree.worldFrame)
        let environment = try SpherePlaneBallisticEnvironment(model: model, equation: equation, sphere: sphere, plane: plane, sphereToBody: .identity, planeToBody: .identity,
            law: HybridProbeModel.contactLaw(), eventID: 10, geometryRevision: 1,
            queryPolicy: CollisionQueryPolicy(absoluteLengthTolerance: 1e-10, relativeLengthTolerance: 1e-10, referenceLength: 1, maximumApproximationError: 0), evolutionPolicy: policy, impactPolicy: impact)
        let history = try HybridContinuationProvider(catalog: environment.catalog, policy: policy, impactPolicy: impact, model: model)
        let contributors = try Contributors(base: smooth, events: history), handler = Handler(contributors: contributors, revisions: ReferenceModelRevisionUpdater())
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "hybrid-profile-probe-v1", backend: "referenceCPU", precision: "float64"), requiredContributors: contributors.schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 3, maximumContributors: 2, maximumContributorBytes: 8192, maximumMetadataBytes: 4096,
                maximumCheckpointBytes: 16384, maximumValidationWork: 8192, maximumValidationScratchBytes: 4096, maximumObservationLeases: 1,
                maximumBatchStates: 1, maximumTransactions: 10000, maximumStepWorkUnits: 10000, maximumWorkBetweenSafePoints: 2), determinism: .sameBuildReplay, workload: "reintegrated-bounce")
        let records = try [smooth.initialRecord(physical: model.descriptor.initialState, equations: equation), history.initialRecord(physical: model.descriptor.initialState)]
        first = try Session(model: model, configuration: configuration, initialState: model.descriptor.initialState, contributors: records, seed: 42, checkpoints: handler)
        second = try Session(model: model, configuration: configuration, initialState: model.descriptor.initialState, contributors: records, seed: 42, checkpoints: handler)
        let trajectory = try IsolatedIntegrationTrajectory(model: model, equations: equation, continuation: smooth, configuration: configuration, checkpoints: handler, integrator: ReferenceExplicitIntegrator())
        evolution = try ReferenceHybridEvolution(trajectory: trajectory, environment: environment, continuation: history,
            admission: DynamicsAdmission(capacity: DynamicsCapacity(maximumBodies: 4, maximumVelocities: 4, maximumBodyWrenches: 0, maximumGeneralizedContributions: 0),
                angularVelocityTolerance: NumericalTolerance(absolute: 1e-10, relative: 1e-10), linearVelocityTolerance: NumericalTolerance(absolute: 1e-10, relative: 1e-10), isCancelled: { cancellation.isCancelled }),
            massPolicy: DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
                linearTolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-12), coordinateScales: [1], energyScale: 1, timeScale: 1))
        self.history = history; self.cancellation = cancellation
    }

    @inline(never) func work() throws -> HybridEvolutionWork {
        try HybridEvolutionWork(numerical: NumericalWork(budget: NumericalBudget(scalarStorage: 100_000, arithmeticOperations: 10_000_000, iterations: 10000)),
            collision: CollisionWork(budget: CollisionBudget(scalarStorage: 1000, operations: 10_000_000, iterations: 1000, records: 10)),
            contact: ContactWork(budget: ContactBudget(operations: 100_000, scalarStorage: 1000, records: 10)),
            loads: LoadWork(budget: LoadBudget(maximumWork: 10000, maximumScalars: 1000, isCancelled: { cancellation.isCancelled })))
    }
}
