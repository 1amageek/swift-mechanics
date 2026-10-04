public enum ContactNormalLaw: Equatable, Sendable {
    case linear(stiffness: Double, damping: Double, maximumPenetration: Double, maximumNormalSpeed: Double)
    case hertz(coefficient: Double, effectiveRadius: Double, maximumPenetration: Double, maximumNormalSpeed: Double)
    case huntCrossley(coefficient: Double, alpha: Double, effectiveRadius: Double, maximumPenetration: Double, maximumNormalSpeed: Double)
    internal func validate() throws(ContactLawError) {
        let k:Double, d:Double, p:Double, v:Double, r:Double?
        switch self {
        case .linear(let stiffness,let damping,let penetration,let speed): k=stiffness; d=damping; p=penetration; v=speed; r=nil
        case .hertz(let coefficient,let radius,let penetration,let speed): k=coefficient; d=0; p=penetration; v=speed; r=radius
        case .huntCrossley(let coefficient,let alpha,let radius,let penetration,let speed): k=coefficient; d=alpha; p=penetration; v=speed; r=radius
        }
        guard k.isFinite, k > 0, d.isFinite, d >= 0, p.isFinite, p > 0, v.isFinite, v > 0 else { throw .invalidMaterial }
        if let r { guard r.isFinite, r > p else { throw .invalidMaterial } }
    }
    internal var hasNormalDamping: Bool {
        switch self { case .linear(_,let d,_,_): d > 0; case .hertz: false; case .huntCrossley(_,let a,_,_,_): a > 0 }
    }
}
