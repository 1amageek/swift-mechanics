public protocol URDFCollisionConfiguring: Sendable {
    func proxy(state: CompiledKinematicState, model: CompiledMechanicalModel, frameRevision: UInt64,
               margin: Double, filter: ColliderFilter, work: inout URDFWork) throws(URDFFailure) -> CollisionProxy
}
