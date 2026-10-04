public enum RepresentationQuality: Equatable, Sendable {
    case exact
    case approximation(maximumDeviationMeters: Double)

    public func validating() throws(ModelError) {
        if case .approximation(let deviation) = self {
            guard deviation.isFinite, deviation >= 0 else { throw .invalidMetadata }
        }
    }
}
