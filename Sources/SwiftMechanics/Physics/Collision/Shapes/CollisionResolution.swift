public enum CollisionResolution: Equatable, Sendable {
    case analytic
    case sampled(maximumFeatureSpacingMeters: Double)

    public func validate() throws(CollisionError) {
        if case .sampled(let spacing) = self {
            guard spacing.isFinite, spacing > 0 else { throw .invalidShape }
        }
    }
}
