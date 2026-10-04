import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct ActuationProbeContext: Sendable {
    typealias Session = RuntimeSession<ReferenceRuntimeCheckpointHandler<ActuatorRuntimeContributors, ReferenceModelRevisionUpdater>>
    let model: CompiledMechanicalModel
    let law: ScalarServo
    let registry: ActuatorRuntimeContributors
    let session: Session
    let budget: ActuationBudget
    let numericalBudget: NumericalBudget
    let tolerance: NumericalTolerance
    let command: DriveCommand

    @inline(never) init() throws {
        let fixture = try MechanicalProbeModel(), model = fixture.model
        let binding = try Self.binding(model: model, kind: .servo)
        let budget = try ActuationBudget(maximumWork: 20_000, maximumScalars: 100, maximumBytes: 4096, maximumBindings: 8, maximumMetadataBytes: 1000)
        var work = ActuationWork(budget: budget)
        let registry = try ActuatorRuntimeContributors(bindings: [binding], codec: FixedActuatorContinuationCodec(), controlBudget: budget, work: &work)
        let state = try ActuatorState(binding: binding, time: 0, primary: 0, mode: .velocity)
        let record = try registry.codec.encode(state, work: &work)
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "actuation-profile-v1", backend: "referenceCPU", precision: "float64"), requiredContributors: registry.schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 3, maximumContributors: 1, maximumContributorBytes: 512, maximumMetadataBytes: 2000,
                maximumCheckpointBytes: 4096, maximumValidationWork: 2000, maximumValidationScratchBytes: 512, maximumObservationLeases: 1,
                maximumBatchStates: 1, maximumTransactions: 100, maximumStepWorkUnits: 10, maximumWorkBetweenSafePoints: 2),
            determinism: .sameBuildReplay, workload: "actuator-history")
        session = try RuntimeSession(model: model, configuration: configuration, initialState: fixture.descriptor.initialState, contributors: [record], seed: 42,
            checkpoints: ReferenceRuntimeCheckpointHandler(contributors: registry, revisions: ReferenceModelRevisionUpdater()))
        law = try ScalarServo(binding: binding, positionGain: 4, velocityGain: 2, integralGain: 2, integralLimit: 10, effortLimit: 3, speedLimit: 10,
            positionDeadband: 0.01, velocityDeadband: 0.01, filterTimeConstant: 0)
        self.model = model; self.registry = registry; self.budget = budget
        numericalBudget = try NumericalBudget(scalarStorage: 100, arithmeticOperations: 10_000, iterations: 0)
        tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-11)
        command = try DriveCommand(mode: .velocity, value: 2.25)
    }

    @inline(never) static func binding(model: CompiledMechanicalModel, kind: ActuatorStateKind) throws -> ActuatorBinding {
        let domain = try ActuatorScalarDomain(primaryLower: kind == .servo ? -10 : -100, primaryUpper: kind == .servo ? 10 : 100,
            secondaryLower: kind == .servo ? -1000 : 0, secondaryUpper: kind == .servo ? 1000 : 0)
        return try ActuatorBinding(actuator: EntityID(kind: .actuator, key: "profile-drive"), joint: EntityID(kind: .joint, key: "compile-probe-hinge"),
            frame: model.descriptor.worldFrame, model: model.stamp, lawRevision: 1, continuationKey: 99, positionIndex: 0, velocityIndex: 0,
            coordinate: .rotation, authority: .dynamicState, stateKind: kind, stateDomain: domain)
    }

    @inline(never) func advance(reject: Bool) throws -> RuntimeTrialOutcome {
        try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try executeTrial(reject: reject, trial: &trial, control: &control)
        }
    }

    @inline(never) private func executeTrial(reject: Bool, trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) -> RuntimeTrialDecision {
        var work = ActuationWork(budget: budget), numerical = NumericalWork(budget: numericalBudget)
        let service: any ActuatorTrialOperating = ReferenceActuatorTrialOperator(codec: registry.codec, drives: ReferenceDriveEvaluator(), registry: registry)
        let response = try service.servo(law: law, command: command, dt: 1, tolerance: tolerance, trial: &trial, control: &control, work: &work, numerical: &numerical)
        try trial.setTime(response.state.time)
        if reject { try trial.setPosition(99, at: 0); _ = try trial.nextRandom() }
        return reject ? .reject : .accept
    }
}
