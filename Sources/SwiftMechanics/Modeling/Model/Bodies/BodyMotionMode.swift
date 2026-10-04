public enum BodyMotionMode: Equatable, Sendable {
    case dynamic, `static`, prescribedKinematic

    public var isForceDriven: Bool { self == .dynamic }
    public var hasPrescribedMotion: Bool { self == .prescribedKinematic }
    public var hasFixedMotion: Bool { self == .static }
    public var permitsReactionObservation: Bool { true }
}
