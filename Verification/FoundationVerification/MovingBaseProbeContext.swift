import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
enum MovingBaseProbeContext {
    typealias Session = RuntimeSession<GeometricMechanismCheckpointHandler>

    @inline(never)
    static func equation(_ fixture: MovingBaseProbeModel) throws -> GeometricMechanismEquation {
        let first = try GeometricFrameEndpoint(body: EntityID(kind: .body, key: "moving-first"), frame: fixture.firstRotorFrame, point: .unitX, axis: .unitX)
        let second = try GeometricFrameEndpoint(body: EntityID(kind: .body, key: "moving-second"), frame: fixture.secondRotorFrame, point: .unitX, axis: .unitX)
        let relation = try GeometricRelation(kind: .alignedAxes, rowIDs: [1, 2], first: first, second: second,
            target: GeometricAnalyticTarget(), scale: 1)
        var work = try MechanismProbeContext.work()
        let geometry = try GeometricConstraintSystem(model: fixture.model, layout: fixture.layout, relations: [relation],
            minimumPosition: [-100, -100], maximumPosition: [100, 100], minimumTime: 0, maximumTime: 2,
            capacity: GeometricConstraintCapacity(maximumBodies: 8, maximumPositions: 8, maximumVelocities: 8,
                maximumRows: 8, maximumMetadataBytes: 65536), work: &work, prescribedMotion: fixture.program)
        let solve = try MechanismProbeContext.policy()
        let projection = try ManifoldProjectionPolicy(constraints: solve.constraints, maximumIterations: 20,
            maximumPathCorrection: 100, maximumMetadataBytes: 65536)
        return try GeometricMechanismEquation(identity: "coupled-moving-base-public", geometry: geometry, drive: [1, 0],
            policy: solve, projection: projection, maximumStageChartCorrection: 0.05,
            publicationBudget: NumericalBudget(scalarStorage: 2_000_000, arithmeticOperations: 100_000_000, iterations: 100_000),
            admission: MechanismProbeContext.admission(), maximumIdentityBytes: 65536)
    }

    @inline(never)
    static func session(_ fixture: MovingBaseProbeModel, equation: GeometricMechanismEquation) throws -> (Session, IntegrationContinuationProvider) {
        let provider = try IntegrationContinuationProvider(descriptor: equation.descriptor, policy: GeometricEvolutionProbeContext.policy(equation))
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "moving-base-public-v1",
            backend: "reference-cpu", precision: "float64"), requiredContributors: provider.schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 4, maximumContributorBytes: 65536,
                maximumMetadataBytes: 65536, maximumCheckpointBytes: 131072, maximumValidationWork: 200000,
                maximumValidationScratchBytes: 131072, maximumObservationLeases: 2, maximumBatchStates: 2,
                maximumTransactions: 1000, maximumStepWorkUnits: 100000, maximumWorkBetweenSafePoints: 4),
            determinism: .sameBuildReplay, workload: "physical-moving-base-coupling")
        let base = ReferenceRuntimeCheckpointHandler(contributors: provider, revisions: ReferenceModelRevisionUpdater())
        let handler = try GeometricMechanismCheckpointHandler(equations: equation, continuation: provider, base: base,
            validationBudget: NumericalBudget(scalarStorage: 2_000_000, arithmeticOperations: 100_000_000, iterations: 100_000))
        return (try Session(model: fixture.model, configuration: configuration, initialState: fixture.model.descriptor.initialState,
            contributors: [provider.initialRecord(physical: fixture.model.descriptor.initialState, equations: equation)],
            seed: 42, checkpoints: handler), provider)
    }
}
