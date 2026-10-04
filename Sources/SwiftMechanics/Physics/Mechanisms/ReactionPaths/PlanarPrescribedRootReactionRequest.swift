/// Owns immutable declarations across the original acceptance phase boundaries.
internal final class PlanarPrescribedRootReactionRequest: Sendable {
    let source: PlanarPrescribedRootReactionInput
    let policy: PlanarPrescribedRootReactionPolicy
    init(source: PlanarPrescribedRootReactionInput, policy: PlanarPrescribedRootReactionPolicy) {
        self.source=source;self.policy=policy
    }
}
