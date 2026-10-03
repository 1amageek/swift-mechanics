public enum ContactLossPolicy: Equatable, Sendable {
    case compliantDampingOnly
    case separateImpact(restitution: Double, thresholdSpeed: Double)
    internal func validate(normal: ContactNormalLaw) throws(ContactLawError) {
        if case .separateImpact(let e,let speed)=self {
            guard e.isFinite, e >= 0, e <= 1, speed.isFinite, speed >= 0 else { throw .invalidMaterial }
            guard !normal.hasNormalDamping else { throw .incompatibleLossPolicy }
        }
    }
}
