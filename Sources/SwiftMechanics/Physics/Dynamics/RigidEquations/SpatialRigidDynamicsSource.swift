/// Immutable retention of the complete actual spatial input across physical phases.
internal final class SpatialRigidDynamicsSource: Sendable {
    let input: RigidDynamicsInput
    init(_ input: RigidDynamicsInput) { self.input = input }
}
