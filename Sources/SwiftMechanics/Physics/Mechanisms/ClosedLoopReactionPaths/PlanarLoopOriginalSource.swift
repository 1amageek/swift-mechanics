/// Extracts the rich original source in a bounded phase before lower Newton/Euler queries.
internal final class PlanarLoopOriginalSource: Sendable {
    let input: PlanarRigidDynamicsInput
    @inline(never)
    init(_ system:PhysicalRigidDynamicsSystem) throws(ClosedLoopReactionError) {
        guard case .planar(let original)=system.input.source else { throw .invalidSupplierEvidence }
        input=original
    }
}
