import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
enum PlanarEvolutionProbeContext {
    typealias Session = RuntimeSession<GeometricMechanismCheckpointHandler>

    @inline(never)
    static func session(_ fixture: FourBarProbeModel, equation: GeometricMechanismEquation, step: Double = 0.01) throws -> (Session, IntegrationContinuationProvider) {
        let provider = try IntegrationContinuationProvider(descriptor: equation.descriptor,
            policy: GeometricEvolutionProbeContext.policy(equation, step: step))
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "planar-four-bar-public-v1",
            backend: "reference-cpu", precision: "float64"), requiredContributors: provider.schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 4, maximumContributorBytes: 65536,
                maximumMetadataBytes: 65536, maximumCheckpointBytes: 131072, maximumValidationWork: 200000,
                maximumValidationScratchBytes: 131072, maximumObservationLeases: 2, maximumBatchStates: 2,
                maximumTransactions: 1000, maximumStepWorkUnits: 100000, maximumWorkBetweenSafePoints: 4),
            determinism: .sameBuildReplay, workload: "planar-four-bar-torque")
        let base = ReferenceRuntimeCheckpointHandler(contributors: provider, revisions: ReferenceModelRevisionUpdater())
        let handler = try GeometricMechanismCheckpointHandler(equations: equation, continuation: provider, base: base,
            validationBudget: equation.publicationBudget)
        let initial = fixture.model.descriptor.initialState
        return (try Session(model: fixture.model, configuration: configuration, initialState: initial,
            contributors: [provider.initialRecord(physical: initial, equations: equation)], seed: 42, checkpoints: handler), provider)
    }
}
