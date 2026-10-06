public struct CoSimulationCoupling: Sendable {
    public enum Exchange: Sendable { case held, interpolated, fixedPoint }
    public let stiffnessNewtonsPerMeter: Double
    public let dampingNewtonSecondsPerMeter: Double
    public let restOffsetMeters: Double
    public let energyAgreement: NumericalTolerance
    public let forceAgreement: NumericalTolerance
    public let powerAgreement: NumericalTolerance
    public let maximumAccumulatedAbsoluteEnergyDefectJoules: Double
    public init(stiffnessNewtonsPerMeter: Double, dampingNewtonSecondsPerMeter: Double,
                restOffsetMeters: Double, exchange: Exchange, delaySeconds: Double,
                energyAgreement: NumericalTolerance, forceAgreement: NumericalTolerance,
                powerAgreement: NumericalTolerance,
                maximumAccumulatedAbsoluteEnergyDefectJoules: Double) throws(CoSimulationFailure) {
        // FIXME(INCOMPLETE_IMPLEMENTATION): Interpolation, delay and iterative exchange reach public coupling admission.
        // Their time/energy and restoration contracts must be implemented and verified before admission.
        guard case .held=exchange, delaySeconds == 0 else { throw .refusal(.unsupportedDomain) }
        guard energyAgreement.relative < 1, forceAgreement.relative < 1, powerAgreement.relative < 1,
              stiffnessNewtonsPerMeter.isFinite, stiffnessNewtonsPerMeter >= 0,
              dampingNewtonSecondsPerMeter.isFinite, dampingNewtonSecondsPerMeter >= 0, restOffsetMeters.isFinite,
              maximumAccumulatedAbsoluteEnergyDefectJoules.isFinite,
              maximumAccumulatedAbsoluteEnergyDefectJoules >= 0 else { throw .refusal(.invalidInput) }
        self.stiffnessNewtonsPerMeter=stiffnessNewtonsPerMeter
        self.dampingNewtonSecondsPerMeter=dampingNewtonSecondsPerMeter; self.restOffsetMeters=restOffsetMeters
        self.energyAgreement=energyAgreement; self.forceAgreement=forceAgreement; self.powerAgreement=powerAgreement
        self.maximumAccumulatedAbsoluteEnergyDefectJoules=maximumAccumulatedAbsoluteEnergyDefectJoules
    }
}
