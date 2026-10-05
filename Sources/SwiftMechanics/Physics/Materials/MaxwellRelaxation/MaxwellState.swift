public struct MaxwellState: Equatable, Sendable {
    public let law: MaxwellLaw, time: Double, stress: Double
    public init(law: MaxwellLaw, time: Double, stress: Double) throws(MaterialError) {
        guard time.isFinite, time >= 0, stress.isFinite, abs(stress) <= law.maximumStress else {
            throw .invalidParameter(name: "MaxwellState")
        }
        self.law = law; self.time = time; self.stress = stress
    }
}
