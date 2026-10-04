import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
enum SleepMechanismProbeContext {
    typealias Session = RuntimeSession<SleepRuntimeCheckpointHandler<ReferenceModelRevisionUpdater>>

    static func owner(_ model: CompiledMechanicalModel) throws -> CheckpointedMechanismSleep {
        try CheckpointedMechanismSleep(identity: "public-checkpointed-gears", model: model,
                                      constraints: MechanismProbeContext.equations(), drive: [0, 0],
                                      solvePolicy: MechanismProbeContext.policy(), admission: MechanismProbeContext.admission(),
                                      policy: MechanismSleepContinuationPolicy(thresholds: MechanismSleepPolicy(maximumCoordinates: 8,
                                                                                                              kineticEnergyThreshold: 1e-8,
                                                                                                              normalizedVelocityThreshold: 1e-8),
                                                                              minimumRestDuration: 0.15, maximumIdentityBytes: 1024),
                                      integration: MechanismProbeContext.integrationPolicy())
    }

    static func session(_ model: CompiledMechanicalModel, owner: CheckpointedMechanismSleep) throws -> Session {
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "sleep-v1", backend: "reference-cpu",
                                                                                               precision: "float64"),
                                                     requiredContributors: owner.schemas,
                                                     capacity: RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 4,
                                                                               maximumContributorBytes: 8192, maximumMetadataBytes: 4096,
                                                                               maximumCheckpointBytes: 16_384, maximumValidationWork: 20_000_000,
                                                                               maximumValidationScratchBytes: 8_000_000, maximumObservationLeases: 2,
                                                                               maximumBatchStates: 2, maximumTransactions: 1000,
                                                                               maximumStepWorkUnits: 100_000, maximumWorkBetweenSafePoints: 4),
                                                     determinism: .sameBuildReplay, workload: "public-connected-gear-sleep")
        let equation = try AffineMechanismEquation(identity: owner.descriptor.identity, model: model, constraints: owner.constraints,
                                                  drive: [0, 0], policy: MechanismProbeContext.policy(), admission: MechanismProbeContext.admission(),
                                                  maximumIdentityBytes: 1024)
        let handler = SleepRuntimeCheckpointHandler(sleep: owner, revisions: ReferenceModelRevisionUpdater())
        return try Session(model: model, configuration: configuration, initialState: model.descriptor.initialState,
                           contributors: [owner.initialRecord(physical: model.descriptor.initialState),
                                          owner.continuation.initialRecord(physical: model.descriptor.initialState, equations: equation)],
                           seed: 42, checkpoints: handler)
    }

    static func history(_ owner: CheckpointedMechanismSleep, _ accepted: RuntimeAcceptedState) throws -> MechanismSleepHistory {
        guard let record = accepted.checkpoint.contributors.first(where: { $0.id == owner.schema.id }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        return try owner.history(record)
    }
}
