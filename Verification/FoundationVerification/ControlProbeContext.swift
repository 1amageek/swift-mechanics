import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct ControlProbeContext: Sendable {
    let fixture: ControlProbeModel
    let policy: ControlPolicy
    let plant: PrismaticControlPlant
    let controller: SampledController
    let clock: ControlClock
    let actuator: ActuatorState

    @inline(never)
    init(disturbance: Double = 0, computedTorque: Bool = false, speedLimit: Double = 100) throws {
        let fixture = try ControlProbeModel()
        let policy = try Self.makePolicy()
        let binding = try ActuatorBinding(actuator: EntityID(kind: .actuator, key: "control-public-servo"),
            joint: fixture.joint, frame: fixture.model.descriptor.worldFrame, model: fixture.model.stamp,
            lawRevision: 1, continuationKey: 81, positionIndex: 0, velocityIndex: 0,
            coordinate: .translation, authority: .dynamicState, stateKind: .servo,
            stateDomain: ActuatorScalarDomain(primaryLower: -10, primaryUpper: 10, secondaryLower: -100, secondaryUpper: 100))
        let servo = try ScalarServo(binding: binding, positionGain: 4, velocityGain: 2, integralGain: 0,
            integralLimit: 10, effortLimit: 3, speedLimit: speedLimit,
            positionDeadband: 0, velocityDeadband: 0, filterTimeConstant: 0)
        let port = try ScalarControlPort(binding: binding, parentAnchorFrame: fixture.parentAnchor)
        var work = NumericalWork(budget: policy.numerical)
        plant = try PrismaticControlPlant(model: fixture.model, port: port, disturbanceNewtons: disturbance, policy: policy, work: &work)
        if computedTorque {
            controller = try SampledController(effortServo: servo, positionAccelerationGain: 0, rateAccelerationGain: 0)
        } else { controller = SampledController(servo: servo, mode: .effort) }
        clock = try ControlClock(epochSeconds: 0, periodSeconds: 0.1, maximumTimeSeconds: 1, maximumTicks: 8)
        actuator = try ActuatorState(binding: binding, time: 0, primary: 0, mode: .effort)
        self.fixture = fixture; self.policy = policy
    }

    @inline(never)
    private static func makePolicy() throws -> ControlPolicy {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let numerical = try NumericalBudget(scalarStorage: 100_000, arithmeticOperations: 10_000_000, iterations: 10_000)
        return try ControlPolicy(maximumMetadataBytes: 16_384, maximumGraphNodes: 4, maximumGraphEdges: 4,
            maximumPayloadBytes: 16_384, maximumPositionMeters: 10, maximumRateMetersPerSecond: 10,
            agreement: tolerance,
            actuation: ActuationBudget(maximumWork: 100_000, maximumScalars: 1000, maximumBytes: 16_384,
                maximumBindings: 4, maximumMetadataBytes: 8192), numerical: numerical,
            dynamics: DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
                linearTolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-12),
                coordinateScales: [1], energyScale: 1, timeScale: 1),
            admission: DynamicsAdmission(capacity: DynamicsCapacity(maximumBodies: 2, maximumVelocities: 1,
                maximumBodyWrenches: 0, maximumGeneralizedContributions: 2),
                angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance),
            inertia: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0),
            integration: Self.integrationPolicy(numerical: numerical), runtimeCapacity: Self.runtimeCapacity(),
            continuation: RuntimeContinuationIdentity(build: "control-public-rk4-v1", backend: "referenceCPU", precision: "float64"))
    }

    @inline(never)
    private static func integrationPolicy(numerical: NumericalBudget) throws -> ExplicitIntegrationPolicy {
        try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: 0.1, minimumStep: 1e-8, maximumStep: 0.1,
            safety: 0.8, minimumFactor: 0.1, maximumFactor: 2,
            scales: [ODEErrorScale(dimension: .length, absoluteSI: 1e-10, relative: 0),
                ODEErrorScale(dimension: .velocity, absoluteSI: 1e-10, relative: 0)], maximumContinuationBytes: 4096,
            budget: IntegrationBudget(maximumCoordinates: 2, maximumAttempts: 16, maximumAcceptedSteps: 16,
                maximumOuterArithmetic: 100_000, supplier: numerical))
    }

    @inline(never)
    private static func runtimeCapacity() throws -> RuntimeCapacity {
        try RuntimeCapacity(maximumPhysicalScalars: 3, maximumContributors: 3, maximumContributorBytes: 16_384,
            maximumMetadataBytes: 16_384, maximumCheckpointBytes: 32_768, maximumValidationWork: 100_000,
            maximumValidationScratchBytes: 16_384, maximumObservationLeases: 2, maximumBatchStates: 1,
            maximumTransactions: 100, maximumStepWorkUnits: 100_000, maximumWorkBetweenSafePoints: 64)
    }

    @inline(never)
    func makeSession(drives: any DriveEvaluating = ReferenceDriveEvaluator()) throws -> any ControlSessionOperating {
        var work = NumericalWork(budget: policy.numerical)
        let factory: any ControlSessionCreating = ReferenceControlSessionFactory(drives: drives,
            equations: RigidEquationKernel(), dynamics: DenseRigidDynamics(), integrator: ReferenceExplicitIntegrator())
        return try factory.make(plant: plant, controller: controller, clock: clock, initialActuator: actuator,
            seed: 42, policy: policy, work: &work)
    }

    final class CancellationOwner: Sendable {
        private struct State: Sendable {
            var session: (any ControlSessionOperating)?
            var invocations: Int = 0
        }
        private let storage = Mutex(State())

        func install(_ session: any ControlSessionOperating) {
            let retired = storage.withLock { state in
                let previous = state.session
                state.session = session
                return previous
            }
            withExtendedLifetime(retired) {}
        }
        func cancelAfterDrive() {
            let active = storage.withLock { state in
                state.invocations += 1
                return state.session
            }
            active?.cancel()
        }
        var invocationCount: Int { storage.withLock { $0.invocations } }
        func clear() {
            let retired = storage.withLock { state in
                let previous = state.session
                state.session = nil
                return previous
            }
            // Release the retained facade outside the shared owner lock.
            withExtendedLifetime(retired) {}
        }
    }

    struct CancellingDrive: DriveEvaluating, Sendable {
        let cancellation: @Sendable () -> Void
        @inline(never)
        func step(law: ScalarServo, state: ActuatorState, sample: ActuatorSample, command: DriveCommand, dt: Double,
                  energyTolerance: NumericalTolerance, work: inout ActuationWork, numerical: inout NumericalWork) throws(ActuationError) -> ActuatorResponse {
            let original: any DriveEvaluating = ReferenceDriveEvaluator()
            let response = try original.step(law: law, state: state, sample: sample, command: command, dt: dt,
                energyTolerance: energyTolerance, work: &work, numerical: &numerical)
            cancellation()
            return response
        }
        func prescribedVelocity(binding: ActuatorBinding, model: CompiledMechanicalModel, time: Double, requested: Double,
                                speedLimit: Double, work: inout ActuationWork) throws(ActuationError) -> PrescribedVelocityCommand {
            let original: any DriveEvaluating = ReferenceDriveEvaluator()
            return try original.prescribedVelocity(binding: binding, model: model, time: time, requested: requested, speedLimit: speedLimit, work: &work)
        }
    }

    @inline(never)
    func observation(_ session: any ControlSessionOperating) throws -> ControlObservation {
        let captured = Mutex<ControlObservation?>(nil)
        try session.observe { (value: ControlObservation) throws(ControlFailure) in
            captured.withLock { $0 = value }
        }
        guard let value = captured.withLock({ $0 }) else { throw FoundationVerificationError.unexpectedFailure }
        return value
    }

    @inline(never)
    func input(_ observation: ControlObservation, effort: Double = 3, computed: Bool = false,
               tick: UInt64? = nil, sampleTime: Double? = nil, sourceTime: Double? = nil) throws -> ControlSampleInput {
        let physical = observation.accepted.checkpoint.physical
        let sourceState = try KinematicState(revision: physical.revision, time: sourceTime ?? physical.time,
            q: physical.q, v: physical.v, acceleration: physical.acceleration)
        let state = try fixture.model.makeState(sourceState)
        let observationPolicy = try ObservationPolicy(maximumBodies: 2, maximumCoordinates: 2, maximumReactionRows: 0, maximumMetadataBytes: 8192)
        var work = NumericalWork(budget: policy.numerical)
        let preparer: any ObservationSourcePreparing = ReferenceObservationSourcePreparer()
        let source = try preparer.prepare(model: fixture.model, state: state, solved: nil, policy: observationPolicy, work: &work)
        let observer: any KinematicObserving = ReferenceKinematicObserver()
        let encoder = try observer.encoder(source: source, joint: fixture.joint, policy: observationPolicy, work: &work)
        let demand: ControlSampleInput.Demand
        if computed {
            demand = .computedTorque(try ComputedTorqueReference(positionMeters: 0, rateMetersPerSecond: 0,
                accelerationMetersPerSecondSquared: 0.7))
        } else { demand = .servo(try DriveCommand(mode: .effort, value: effort)) }
        return ControlSampleInput(encoder: encoder, sampleTickTime: sampleTime ?? physical.time,
            tick: tick ?? observation.controller.tick, demand: demand,
            commandDimension: computed ? .acceleration : .force)
    }
}
