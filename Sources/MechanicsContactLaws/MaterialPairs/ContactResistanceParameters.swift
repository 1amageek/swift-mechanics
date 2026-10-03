public struct ContactResistanceParameters: Equatable, Sendable {
    public let rollingCoefficient: Double
    public let spinningCoefficient: Double
    public let angularRegularization: Double
    public init(rollingCoefficient: Double, spinningCoefficient: Double, angularRegularization: Double) throws(ContactLawError) {
        guard rollingCoefficient.isFinite, rollingCoefficient >= 0, spinningCoefficient.isFinite, spinningCoefficient >= 0,
              angularRegularization.isFinite, angularRegularization > 0 else { throw .invalidMaterial }
        self.rollingCoefficient=rollingCoefficient; self.spinningCoefficient=spinningCoefficient; self.angularRegularization=angularRegularization
    }
}
