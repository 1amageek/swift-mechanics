import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
enum LoadedSleepProbeContext {
    typealias Session = RuntimeSession<LoadedSleepRuntimeCheckpointHandler<ReferenceModelRevisionUpdater>>
    @inline(never)
    static func owner(_ fixture: LoadedSleepProbeModel, stiffness: Double = 20, energyScale: Double = 7) throws -> LoadedCheckpointedMechanismSleep {
        let law = try PolynomialSpringDamper(coordinateKind: .translation, restCoordinate: 0, quadraticStiffness: stiffness,
            linearDamping: 0, maximumDisplacement: 100, maximumRate: 100)
        let terms = [StationaryScalarLoad(id: 1, coordinateID: 10, law: law), StationaryScalarLoad(id: 2, coordinateID: 20, law: law)]
        let gravity = try AffineGravity(frame: fixture.model.tree.worldFrame, accelerationAtOrigin: Vector3(0, -10, 0))
        let changed = try AffineGravity(frame: fixture.model.tree.worldFrame, accelerationAtOrigin: Vector3(0, -8, 0))
        let catalog = try StationaryLoadCatalog(model: fixture.model, layout: fixture.layout,
            programs: [StationaryLoadProgram(id: 1, revision: 1, gravity: gravity, terms: terms),
                       StationaryLoadProgram(id: 2, revision: 1, gravity: changed, terms: terms)],
            capacity: StationaryLoadCapacity(maximumPrograms: 2, maximumTermsPerProgram: 2,
                maximumCoordinates: 2, maximumMetadataBytes: 65536))
        let original = try MechanismProbeContext.policy()
        let dynamics = try DynamicsSolvePolicy(capability: original.dynamics.capability, linearTolerance: original.dynamics.linearTolerance,
            coordinateScales: fixture.layout.scales, energyScale: energyScale, timeScale: fixture.layout.timeScale)
        let previous = original.constraints
        let constraints = try ConstraintSolvePolicy(evaluation: previous.evaluation, diagonalMetric: previous.diagonalMetric,
            energyScale: energyScale, rankPolicy: previous.rankPolicy, rankRelativeTolerance: previous.rankRelativeTolerance,
            originalResidualTolerance: previous.originalResidualTolerance, maximumCorrection: previous.maximumCorrection,
            nonlinear: previous.nonlinear, linearCapability: previous.linearCapability, linearTolerance: previous.linearTolerance)
        let solve = try MechanismSolvePolicy(dynamics: dynamics, constraints: constraints,
            maximumCoordinates: 8, maximumRows: 8, originalTolerance: 1e-8)
        return try LoadedCheckpointedMechanismSleep(identity: "loaded-sleep-public", model: fixture.model, constraints: fixture.constraints,
            drive: [0, 0], solvePolicy: solve, admission: MechanismProbeContext.admission(),
            policy: MechanismSleepContinuationPolicy(thresholds: MechanismSleepPolicy(maximumCoordinates: 8,
                kineticEnergyThreshold: 1e-8, normalizedVelocityThreshold: 1e-8), minimumRestDuration: 0.15, maximumIdentityBytes: 65536),
            integration: integration(), catalog: catalog, initialSelection: StationaryLoadSelection(programID: 1, revision: 1, generation: 0))
    }

    static func integration() throws -> ExplicitIntegrationPolicy {
        try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: 0.1, minimumStep: 1e-8, maximumStep: 0.1,
            safety: 0.8, minimumFactor: 0.1, maximumFactor: 2,
            scales: [ODEErrorScale(dimension: .length, absoluteSI: 1e-7, relative: 0),
                     ODEErrorScale(dimension: .length, absoluteSI: 1e-7, relative: 0),
                     ODEErrorScale(dimension: .velocity, absoluteSI: 1e-7, relative: 0),
                     ODEErrorScale(dimension: .velocity, absoluteSI: 1e-7, relative: 0)],
            maximumContinuationBytes: 65536, budget: IntegrationBudget(maximumCoordinates: 4, maximumAttempts: 1000,
                maximumAcceptedSteps: 1000, maximumOuterArithmetic: 1_000_000,
                supplier: NumericalBudget(scalarStorage: 1_000_000, arithmeticOperations: 100_000_000, iterations: 100_000)))
    }

    static func loadBudget() throws -> LoadBudget { try LoadBudget(maximumWork: 10000, maximumScalars: 64) }

    @inline(never)
    static func session(_ fixture: LoadedSleepProbeModel, owner: LoadedCheckpointedMechanismSleep) throws -> Session {
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "loaded-sleep-public-v1",
            backend: "reference-cpu", precision: "float64"), requiredContributors: owner.schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 4, maximumContributorBytes: 131072,
                maximumMetadataBytes: 262144, maximumCheckpointBytes: 262144, maximumValidationWork: 20000000,
                maximumValidationScratchBytes: 8000000, maximumObservationLeases: 2, maximumBatchStates: 2,
                maximumTransactions: 1000, maximumStepWorkUnits: 100000, maximumWorkBetweenSafePoints: 4),
            determinism: .sameBuildReplay, workload: "nonzero-gravity-passive-sleep-wake")
        let handler = LoadedSleepRuntimeCheckpointHandler(sleep: owner, revisions: ReferenceModelRevisionUpdater())
        return try Session(model: fixture.model, configuration: configuration, initialState: fixture.model.descriptor.initialState,
            contributors: [owner.initialRecord(physical: fixture.model.descriptor.initialState),
                           owner.initialIntegrationRecord(physical: fixture.model.descriptor.initialState)], seed: 42, checkpoints: handler)
    }

    static func history(_ owner: LoadedCheckpointedMechanismSleep, _ accepted: RuntimeAcceptedState) throws -> LoadedMechanismSleepHistory {
        guard let record = accepted.checkpoint.contributors.first(where: { $0.id == owner.schema.id }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        return try owner.history(record)
    }
}
