public struct GeneralizedAlphaParameters: Equatable, Sendable {
    public let method: StructuralImplicitMethod
    public let alphaM: Double
    public let alphaF: Double
    public let beta: Double
    public let gamma: Double
    public let spectralRadiusInfinity: Double?
    /// Standard second-order generalized-alpha coefficients; rhoInfinity is in [0,1].
    public init(spectralRadiusInfinity rho: Double) throws(ImplicitMethodCause) {
        guard rho.isFinite, rho >= 0, rho <= 1 else { throw .invalidInput }
        method = .generalizedAlpha; alphaM = (2*rho-1)/(rho+1); alphaF = rho/(rho+1)
        gamma = 0.5-alphaM+alphaF
        let value = 1-alphaM+alphaF; beta = value*value/4
        spectralRadiusInfinity = rho
    }
    /// HHT uses its conventional negative alpha parameter in [-1/3,0].
    public static func hht(alpha: Double) throws(ImplicitMethodCause) -> Self {
        guard alpha.isFinite, alpha >= -1.0/3.0, alpha <= 0 else { throw .invalidInput }
        return Self(alpha: alpha)
    }
    private init(alpha: Double) {
        method = .hht; alphaM = 0; alphaF = -alpha; gamma = 0.5-alpha
        beta = (1-alpha)*(1-alpha)/4; spectralRadiusInfinity = nil
    }
}
