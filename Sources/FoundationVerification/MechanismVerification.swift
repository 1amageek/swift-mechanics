import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsDynamics
import MechanicsCompiler
import MechanicsJoints
import MechanicsRuntime
import MechanicsIntegration
import MechanicsMechanisms

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func verifyMechanisms() throws {
        try verifyMechanismEvolution()
        try verifyMechanismBreak()
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyMechanismEvolution() throws {
        let model = try MechanismProbeContext.model(), equation = try MechanismProbeContext.equation(model)
        let (session, continuation) = try MechanismProbeContext.session(model, equation: equation)
        defer { _ = session.shutdown() }

        let prefix = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        let evolved = try ReferenceExplicitIntegrator().advance(session, model: model, equations: equation, continuation: continuation, to: 0.2)
        try require(abs(evolved.accepted.checkpoint.physical.q[0] - 0.04) < 1e-9)
        try require(abs(evolved.accepted.checkpoint.physical.q[1] + 0.02) < 1e-9)
        _ = try session.restart(prefix, codec: NativeRuntimeCheckpointCodec())
        let replay = try ReferenceExplicitIntegrator().advance(session, model: model, equations: equation, continuation: continuation, to: 0.2)
        try require(replay.accepted == evolved.accepted)
        _ = try session.restart(prefix, codec: NativeRuntimeCheckpointCodec())
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyMechanismBreak() throws {
        let model = try MechanismProbeContext.model(), equation = try MechanismProbeContext.equation(model)
        let (session, _) = try MechanismProbeContext.session(model, equation: equation)
        defer { _ = session.shutdown() }
        let source = session.snapshot(), system = try MechanismProbeContext.system(model)
        var w = try MechanismProbeContext.work(), d = try MechanismProbeContext.work()
        var r = try MechanismProbeContext.work(), l = try MechanismProbeContext.work()
        let solver: any ConstrainedMechanismSolving = MassWeightedMechanismSolver()
        let motion = try solver.acceleration(system, sample: MechanismProbeContext.sample(), drive: [6, 0], policy: MechanismProbeContext.policy(), work: &w, dynamicsWork: &d, rankWork: &r, linearWork: &l)
        try require(abs(motion.values[0] - 2) < 1e-9 && abs(motion.values[1] + 1) < 1e-9)
        try require(abs(motion.generalizedReaction[0] + 2) < 1e-9 && abs(motion.generalizedReaction[1] + 4) < 1e-9)
        let tolerance = try NumericalTolerance(absolute: 1e-9, relative: 1e-9)
        let policy = try DetachedLeafPolicy(maximumBodies: 8, maximumCoordinates: 16, translation: tolerance, rotation: tolerance, linearVelocity: tolerance, angularVelocity: tolerance, kineticEnergy: tolerance, linearMomentum: tolerance, angularMomentum: tolerance)
        let builder: any DetachedLeafTransitionBuilding = ReferenceDetachedLeafTransitionBuilder()
        let transition = try builder.detach(model: model, state: source.physical, joint: MechanismProbeContext.id(.joint, "a"), connector: MechanismProbeContext.id(.joint, "free-a"), parentAnchor: MechanismProbeContext.id(.frame, "free-parent"), childAnchor: MechanismProbeContext.id(.frame, "free-child"), policy: policy, admission: MechanismProbeContext.admission(), work: &w, dynamicsWork: &d)
        let breaker: any MechanismBreaking = RuntimeMechanismBreak()
        guard let prepared = try breaker.prepare(source: source, transition: transition, reaction: motion, thresholdSI: 1, eventID: 7, maximumEventBytes: 1024, work: &w) else { throw FoundationVerificationError.analyticCheckFailed }
        let current = session.configuration
        let configuration = try RuntimeConfiguration(continuation: current.continuation, requiredContributors: prepared.contributor.schemas, capacity: current.capacity, determinism: current.determinism, workload: current.workload)
        let handler = try ReferenceRuntimeCheckpointHandler(contributors: prepared.contributor, revisions: ReferenceModelRevisionUpdater())
        let replaced = try breaker.publish(prepared, session: session, configuration: configuration, contributors: [prepared.contributor.record], checkpoints: handler)
        try require(replaced.physical.stamp.revision == 2 && replaced.checkpoint.physical.q.count == 8 && replaced.checkpoint.physical.v.count == 7)
        try require(replaced.checkpoint.random == source.checkpoint.random && replaced.checkpoint.acceptedSteps == source.checkpoint.acceptedSteps + 1)
        let bytes = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        _ = try session.restart(bytes, codec: NativeRuntimeCheckpointCodec())
        try require(session.snapshot() == replaced)
        var refused = false
        do { _ = try breaker.publish(prepared, session: session, configuration: configuration, contributors: [prepared.contributor.record], checkpoints: handler) }
        catch { refused = true }
        try require(refused && session.snapshot() == replaced)
    }
}
