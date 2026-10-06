public struct DahlFrictionLaw: Equatable, Sendable {
    public let stiffness: Double, limitingForce: Double, viscousCoefficient: Double, maximumSpeed: Double
    public let limitingDeflection: Double
    public init(stiffness: Double, limitingForce: Double, viscousCoefficient: Double, maximumSpeed: Double) throws(LoadError) {
        guard stiffness.isFinite, limitingForce.isFinite, viscousCoefficient.isFinite, maximumSpeed.isFinite,
              stiffness > 0, limitingForce > 0, viscousCoefficient >= 0, maximumSpeed > 0 else { throw .invalidPassiveLaw }
        let deflection = limitingForce / stiffness
        guard deflection.isFinite, deflection > 0 else { throw .invalidPassiveLaw }
        self.stiffness = stiffness; self.limitingForce = limitingForce
        self.viscousCoefficient = viscousCoefficient; self.maximumSpeed = maximumSpeed; self.limitingDeflection = deflection
    }
}
