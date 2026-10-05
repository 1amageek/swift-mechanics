public struct DahlFrictionState: Equatable, Sendable {
    public let law: DahlFrictionLaw, time: Double, deflection: Double
    public init(law: DahlFrictionLaw, time: Double, deflection: Double) throws(LoadError) {
        guard time.isFinite, time >= 0, deflection.isFinite, abs(deflection) <= law.limitingDeflection else { throw .invalidInput }
        self.law = law; self.time = time; self.deflection = deflection
    }
}
