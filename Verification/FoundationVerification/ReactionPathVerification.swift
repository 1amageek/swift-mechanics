import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func verifyReactionPaths() throws {
        let model = try ReactionPathProbeContext.model()
        try checkReactionBalance(ReactionPathProbeContext.system(model))
        try checkReactionAmbiguity(ReactionPathProbeContext.system(model, generalized: true))
        print("Reaction path runtime verification passed: physical support/action-reaction and nonunique allocation refusal.")
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkReactionBalance(_ system: RigidDynamicsSystem) throws {
        var work = try MechanismProbeContext.work(), load = LoadWork(budget: try LoadBudget(maximumWork: 100, maximumScalars: 0))
        let service: any TreeReactionRecovering = TreeReactionRecovery()
        let report = try service.recover(system, acceleration: [-10.0 / 3], topology: .completeTree,
                                         outputFrame: system.input.snapshot.tree.worldFrame,
                                         policy: ReactionPathProbeContext.policy(), loadWork: &load, work: &work)
        guard let joint = report.joints.first, let support = report.support else { throw FoundationVerificationError.analyticCheckFailed }
        try require(abs(joint.parentOnChild.force.y - 40.0 / 3) < 1e-9 && abs(joint.parentOnChild.torque.z) < 1e-9)
        try require(abs(joint.childOnParent.force.y + 40.0 / 3) < 1e-9 && joint.referencePointWorld == .zero)
        try require(abs(support.supportOnRoot.force.y - 70.0 / 3) < 1e-9)
        try require(report.maximumScaledOriginalGeneralizedResidual < 1e-9 && joint.temporalMeaning == .instantaneousContinuousForce)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkReactionAmbiguity(_ system: RigidDynamicsSystem) throws {
        var work = try MechanismProbeContext.work(), load = LoadWork(budget: try LoadBudget(maximumWork: 100, maximumScalars: 0))
        let policy = try ReactionPathProbeContext.policy()
        var refused = false
        do throws(ReactionPathError) {
            _ = try TreeReactionRecovery().recover(system, acceleration: [-10.0 / 3], topology: .completeTree,
                                                    outputFrame: system.input.snapshot.tree.worldFrame,
                                                    policy: policy, loadWork: &load, work: &work)
        } catch { try require(error == .nonuniqueGeneralizedAllocation); refused = true }
        try require(refused)
    }
}
