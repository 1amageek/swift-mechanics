import MechanicsCore

public enum AnchorPlacement: Equatable, Sendable {
    case fixed(RigidTransform)
    case prescribed
}
