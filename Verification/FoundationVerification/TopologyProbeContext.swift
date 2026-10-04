import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
enum TopologyProbeContext {
    typealias Session = RuntimeSession<TopologyCheckpointHandler>

    static func work() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 2_000_000,
            arithmeticOperations: 100_000_000, iterations: 100_000))
    }

    static func tolerance() throws -> NumericalTolerance {
        try NumericalTolerance(absolute: 1e-8, relative: 1e-8)
    }

    static func policy() throws -> SubtreeReleasePolicy {
        let t = try tolerance()
        return try SubtreeReleasePolicy(maximumBodies: 4, maximumCoordinates: 32,
            translation: t, rotation: t, linearVelocity: t, angularVelocity: t,
            kineticEnergy: t, linearMomentum: t, angularMomentum: t)
    }

    static func admission() throws -> DynamicsAdmission {
        DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 4, maximumVelocities: 16,
            maximumBodyWrenches: 4, maximumGeneralizedContributions: 4),
            angularVelocityTolerance: try tolerance(), linearVelocityTolerance: try tolerance())
    }

    static func dynamics(_ count: Int) throws -> DynamicsSolvePolicy {
        try DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            linearTolerance: LinearTolerance(absoluteResidual: 1e-8, relativeResidual: 1e-8, pivotThreshold: 1e-12),
            coordinateScales: [Double](repeating: 1, count: count), energyScale: 1, timeScale: 1)
    }

    static func actuationBudget() throws -> ActuationBudget {
        try ActuationBudget(maximumWork: 100000, maximumScalars: 1000, maximumBytes: 16384,
            maximumBindings: 4, maximumMetadataBytes: 4096)
    }

    static func historyPolicy() throws -> TopologyContinuationPolicy {
        try TopologyContinuationPolicy(maximumEvents: 2, maximumBytes: 16384,
            maximumMetadataBytes: 4096, maximumWork: 100000)
    }

    static func capacity() throws -> RuntimeCapacity {
        try RuntimeCapacity(maximumPhysicalScalars: 128, maximumContributors: 4,
            maximumContributorBytes: 65536, maximumMetadataBytes: 8192, maximumCheckpointBytes: 131072,
            maximumValidationWork: 200000, maximumValidationScratchBytes: 65536,
            maximumObservationLeases: 2, maximumBatchStates: 2, maximumTransactions: 1000,
            maximumStepWorkUnits: 100000, maximumWorkBetweenSafePoints: 4)
    }

    static func configuration(_ schemas: [RuntimeContributorSchema]) throws -> RuntimeConfiguration {
        try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "topology-public-v1",
            backend: "reference-cpu", precision: "float64"), requiredContributors: schemas,
            capacity: capacity(), determinism: .sameBuildReplay, workload: "subtree-release")
    }

    static func rules(_ fixture: FourBarProbeModel) throws -> [TopologyReleaseRule] {
        func rule(_ id: UInt64, joint: EntityID, root: EntityID, key: String) throws -> TopologyReleaseRule {
            try TopologyReleaseRule(id: id, joint: joint, connector: EntityID(kind: .joint, key: key),
                parentAnchor: EntityID(kind: .frame, key: key + "-parent"),
                childAnchor: EntityID(kind: .frame, key: key + "-child"), subtreeRoot: root, metric: .explicitRelease)
        }
        return try [rule(1, joint: fixture.crankJoint, root: fixture.crank, key: "released-crank"),
            rule(2, joint: fixture.couplerJoint, root: fixture.coupler, key: "released-coupler")]
    }

    @inline(never)
    static func session(_ fixture: FourBarProbeModel) throws -> (Session, TopologyHistoryContributor, ActuatorBinding) {
        let model = fixture.model
        var velocity = model.descriptor.initialState.v
        velocity[fixture.crankIndex] = 0.4; velocity[fixture.couplerIndex] = -0.3; velocity[fixture.rockerIndex] = 0.2
        let initial = try KinematicState(revision: model.stamp.revision, time: 0, q: model.descriptor.initialState.q,
            v: velocity, acceleration: model.descriptor.initialState.acceleration)
        let history = try TopologyHistoryContributor(model: model,
            catalog: TopologyEventCatalog(initialModel: model.stamp, initialTime: 0, initialSequence: 0,
                rules: rules(fixture), policy: historyPolicy()), policy: historyPolicy())
        let binding = try ActuatorBinding(actuator: EntityID(kind: .actuator, key: "rocker-servo"),
            joint: fixture.rockerJoint, frame: model.descriptor.worldFrame, model: model.stamp,
            lawRevision: 3, continuationKey: 19, positionIndex: fixture.rockerIndex, velocityIndex: fixture.rockerIndex,
            coordinate: .rotation, authority: .dynamicState, stateKind: .servo,
            stateDomain: ActuatorScalarDomain(primaryLower: -10, primaryUpper: 10, secondaryLower: -1000, secondaryUpper: 1000))
        var work = ActuationWork(budget: try actuationBudget())
        let provider = try ActuatorRuntimeContributors(bindings: [binding], codec: FixedActuatorContinuationCodec(),
            controlBudget: actuationBudget(), work: &work)
        let record = try FixedActuatorContinuationCodec().encode(ActuatorState(binding: binding, time: 0,
            primary: 0.4, secondary: -0.7, mode: .position, sequence: 8), work: &work)
        let registry = try TopologyRuntimeContributors(providers: [history, provider], capacity: capacity())
        return (try Session(model: model, configuration: configuration(registry.schemas), initialState: initial,
            contributors: [history.record, record], seed: 42,
            checkpoints: TopologyCheckpointHandler(history: history, contributors: registry)), history, binding)
    }

    @inline(never)
    static func prepare(_ session: Session, history: TopologyHistoryContributor,
                        binding: ActuatorBinding, rule: TopologyReleaseRule) throws -> PreparedTopologyPublication {
        var outer = try work(), numerical = try work()
        let builder: any SubtreeReleaseBuilding = ReferenceSubtreeReleaseBuilder()
        let release = try builder.release(model: history.model, state: session.snapshot().physical,
            joint: rule.joint, connector: rule.connector, parentAnchor: rule.parentAnchor, childAnchor: rule.childAnchor,
            policy: policy(), admission: admission(), work: &outer, dynamicsWork: &numerical)
        var load = LoadWork(budget: try LoadBudget(maximumWork: 100000, maximumScalars: 100000))
        let reconciler: any SubtreeAccelerationPreparing = ReferenceSubtreeAccelerationPreparer()
        let target = try reconciler.prepare(release, gravity: nil, bodyWrenches: [], generalizedForces: [],
            drive: [Double](repeating: 0, count: release.target.tree.layout.velocityCount), admission: admission(),
            policy: dynamics(release.target.tree.layout.velocityCount), work: &numerical, loadWork: &load)
        var actuation = ActuationWork(budget: try actuationBudget())
        let publisher: any TopologyTransitionPreparing = ReferenceTopologyTransitionPreparer()
        return try publisher.prepare(source: session.snapshot(), sourceConfiguration: session.configuration,
            transition: target, history: history, observation: .explicit(release), ruleID: rule.id,
            dispositions: [.appendHistory, .migrateScalarActuator(binding: binding, controlBudget: try actuationBudget())],
            targetConfiguration: configuration(history.schemas + session.configuration.requiredContributors.filter { $0.category == .actuator }),
            work: &outer, actuationWork: &actuation)
    }
}
