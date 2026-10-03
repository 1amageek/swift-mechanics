public enum PatchRepresentation: Sendable {
    case rigidPlane(RigidPressurePlane)
    case compliantBody(PressureBody)
    case unsupportedRigidSurface
}
