public enum HeightfieldMotion: Equatable, Sendable {
    case staticSurface
    case prescribedRigidSnapshots
    case deformingSnapshots
    case dynamicConcaveBody
}
