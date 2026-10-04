/// Immutable retention of the complete actual planar input across physical phases.
internal final class PlanarRigidDynamicsSource: Sendable {
    let input: PlanarRigidDynamicsInput
    init(_ input: PlanarRigidDynamicsInput) { self.input = input }
}
