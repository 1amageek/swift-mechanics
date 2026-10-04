import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func verifyTopologyContinuation() throws {
        let fixture = try FourBarProbeModel()
        let (session, history, binding) = try TopologyProbeContext.session(fixture)
        defer { _ = session.shutdown() }
        let source = session.snapshot()
        let first = try TopologyProbeContext.prepare(session, history: history, binding: binding, rule: history.catalog.rules[0])
        try require(abs(fixture.originalKineticEnergy(q: source.physical.state.q, v: source.physical.state.v)
            - first.transition.release.sourceEnergy.kineticEnergy) < 1e-8)
        try verifyTopologyPhysical(first)
        let publisher: any TopologyTransitionPreparing = ReferenceTopologyTransitionPreparer()
        _ = try publisher.publish(first, session: session)
        try verifyTopologyActuator(first)
        let second = try TopologyProbeContext.prepare(session, history: first.handler.history,
            binding: first.actuatorMigrations[0].target.binding, rule: history.catalog.rules[1])
        try verifyTopologyPhysical(second)
        let final = try publisher.publish(second, session: session)
        try require(second.handler.history.events.map { $0.id } == [1, 2])
        try require(second.handler.history.events.map { $0.acceptedTime } == [0, 0])
        try require(second.handler.history.events.map { $0.acceptedSequence } == [1, 2])
        try require(final.checkpoint.acceptedSteps == 2 && final.checkpoint.random == source.checkpoint.random)
        let bytes = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        var refused = false
        do { _ = try publisher.publish(second, session: session) } catch { refused = true }
        try require(refused && session.snapshot() == final)
        try verifyTopologyReexecution(fixture, bytes: bytes)
        try verifyTopologyColdRestart(second, bytes: bytes, expected: final.checkpoint)
        print("AF22 topology: two cuts, original force, servo migration, replay and cold restart passed")
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyTopologyPhysical(_ prepared: PreparedTopologyPublication) throws {
        let release = prepared.transition.release
        let after = try release.target.evaluate(release.target.makeState(release.incomingPhysical))
        for before in release.sourceSnapshot.bodies {
            let body = try after.body(before.body)
            try require(try body.motion.pose.translation.subtracting(before.motion.pose.translation).magnitude() < 1e-8)
            try require(try body.motion.velocity.linear.subtracting(before.motion.velocity.linear).magnitude() < 1e-8)
            try require(try body.motion.velocity.angular.subtracting(before.motion.velocity.angular).magnitude() < 1e-8)
            let relative = try body.motion.pose.rotation.conjugated().multiplied(by: before.motion.pose.rotation)
            try require(try relative.rotationVector().magnitude() < 1e-8)
        }
        let system = prepared.transition.system, n = system.velocityCount
        for row in 0..<n {
            var inertial = system.inertialBias[row]
            for column in 0..<n { inertial += system.massMatrix[row*n + column] * prepared.transition.physical.acceleration[column] }
            try require(abs(inertial - (try system.forces.total(at: row)) - prepared.transition.drive[row]) < 1e-8)
        }
        try require(prepared.transition.physical.q == release.incomingPhysical.q
            && prepared.transition.physical.v == release.incomingPhysical.v)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyTopologyActuator(_ prepared: PreparedTopologyPublication) throws {
        try require(prepared.actuatorMigrations.count == 1)
        let migration = prepared.actuatorMigrations[0], state = migration.target, b = state.binding
        try require(state.primary == migration.source.primary && state.secondary == migration.source.secondary
            && state.sequence == migration.source.sequence && state.mode == migration.source.mode && state.time == migration.source.time)
        let law = try ScalarServo(binding: b, positionGain: 2, velocityGain: 1, integralGain: 0.5,
            integralLimit: 10, effortLimit: 100, speedLimit: 100, positionDeadband: 0, velocityDeadband: 0, filterTimeConstant: 0.2)
        let sample = try ActuatorSample(binding: b, time: state.time,
            position: prepared.transition.physical.q[b.positionIndex], velocity: prepared.transition.physical.v[b.velocityIndex])
        var work = ActuationWork(budget: try TopologyProbeContext.actuationBudget()), numerical = try TopologyProbeContext.work()
        let result = try ReferenceDriveEvaluator().step(law: law, state: state, sample: sample,
            command: DriveCommand(mode: .position, value: 1), dt: 0.1,
            energyTolerance: TopologyProbeContext.tolerance(), work: &work, numerical: &numerical)
        try require(result.state.sequence == state.sequence + 1 && result.state.time == 0.1)
        let codec: any ActuatorContinuationCoding = FixedActuatorContinuationCodec()
        let bytes = try codec.encode(result.state, work: &work)
        try require(try codec.decode(bytes, binding: b, work: &work) == result.state)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyTopologyReexecution(_ fixture: FourBarProbeModel, bytes: [UInt8]) throws {
        let (session, history, binding) = try TopologyProbeContext.session(fixture)
        defer { _ = session.shutdown() }
        let first = try TopologyProbeContext.prepare(session, history: history, binding: binding, rule: history.catalog.rules[0])
        let publisher: any TopologyTransitionPreparing = ReferenceTopologyTransitionPreparer()
        _ = try publisher.publish(first, session: session)
        let second = try TopologyProbeContext.prepare(session, history: first.handler.history,
            binding: first.actuatorMigrations[0].target.binding, rule: history.catalog.rules[1])
        _ = try publisher.publish(second, session: session)
        try require(try session.checkpoint(codec: NativeRuntimeCheckpointCodec()) == bytes)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyTopologyColdRestart(_ prepared: PreparedTopologyPublication,
                                                bytes: [UInt8], expected: RuntimeCheckpoint) throws {
        let target = prepared.transition.release.target, savedHistory = prepared.handler.history
        let bootstrap = try TopologyHistoryContributor(model: target,
            catalog: TopologyEventCatalog(initialModel: target.stamp, initialTime: prepared.transition.physical.time,
                initialSequence: 0, rules: savedHistory.catalog.rules, policy: savedHistory.policy), policy: savedHistory.policy)
        let providers = prepared.handler.contributors.providers.filter { $0.schemas != savedHistory.schemas } + [bootstrap]
        let registry = try TopologyRuntimeContributors(providers: providers, capacity: prepared.configuration.capacity)
        let handler = try TopologyCheckpointHandler(history: savedHistory, contributors: prepared.handler.contributors,
            bootstrap: bootstrap, physical: target.makeState(prepared.transition.physical), bootstrapContributors: registry)
        let records = prepared.contributors.filter { $0.id != bootstrap.schema.id } + [bootstrap.record]
        let cold = try TopologyProbeContext.Session(model: target, configuration: prepared.configuration,
            initialState: prepared.transition.physical, contributors: records, seed: 42, checkpoints: handler)
        defer { _ = cold.shutdown() }
        let initial = cold.snapshot().checkpoint
        let advanced = try RuntimeCheckpoint(model: initial.model, continuation: initial.continuation,
            physical: initial.physical, contributors: initial.contributors, random: initial.random, acceptedSteps: 1)
        var refused = false
        do { _ = try handler.admit(advanced, model: target, configuration: prepared.configuration, cancellation: nil) }
        catch { refused = true }
        try require(refused && cold.snapshot().checkpoint == initial)
        try require(try cold.restart(bytes, codec: NativeRuntimeCheckpointCodec()).checkpoint == expected)
        try require(try cold.restart(bytes, codec: NativeRuntimeCheckpointCodec()).checkpoint == expected)
        try require(try cold.checkpoint(codec: NativeRuntimeCheckpointCodec()) == bytes)
    }
}
