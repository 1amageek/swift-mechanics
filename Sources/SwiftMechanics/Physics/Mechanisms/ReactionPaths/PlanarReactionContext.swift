/// One immutable original-source owner prevents rich source extraction from remaining live in body-query frames.
internal final class PlanarReactionContext: Sendable {
    let system: PhysicalRigidDynamicsSystem
    let input: PlanarRigidDynamicsInput
    @inline(never)
    init(_ system:PhysicalRigidDynamicsSystem) throws(ReactionPathError) {
        guard case .planar(let original)=system.input.source else { throw .dynamics(.dimensionMismatch) }
        self.system=system;input=original
    }
}
