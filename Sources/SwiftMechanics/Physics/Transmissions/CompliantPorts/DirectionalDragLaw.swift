public struct DirectionalDragLaw: Sendable {
    public let positiveViscous: Double
    public let negativeViscous: Double
    public let positiveCoulomb: Double
    public let negativeCoulomb: Double
    public let maximumAbsVelocity: Double
    public init(positiveViscous: Double,negativeViscous: Double,positiveCoulomb: Double,negativeCoulomb: Double,maximumAbsVelocity: Double) throws(TransmissionError) {
        guard positiveViscous.isFinite, positiveViscous >= 0, negativeViscous.isFinite, negativeViscous >= 0,
              positiveCoulomb.isFinite, positiveCoulomb >= 0, negativeCoulomb.isFinite, negativeCoulomb >= 0,
              maximumAbsVelocity.isFinite, maximumAbsVelocity > 0 else { throw .invalidInput }
        self.positiveViscous=positiveViscous; self.negativeViscous=negativeViscous; self.positiveCoulomb=positiveCoulomb
        self.negativeCoulomb=negativeCoulomb; self.maximumAbsVelocity=maximumAbsVelocity
    }
}
