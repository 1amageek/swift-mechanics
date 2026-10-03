public enum ContactCohesionLaw: Equatable, Sendable {
    case none
    case reversibleLinear(tensileLimit: Double, range: Double)
    internal func validate() throws(ContactLawError) {
        if case .reversibleLinear(let force, let range)=self {
            guard force.isFinite, force > 0, range.isFinite, range > 0 else { throw .invalidMaterial }
        }
    }
}
