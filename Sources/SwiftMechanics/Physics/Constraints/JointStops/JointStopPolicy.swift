public struct JointStopPolicy: Sendable {
    public let observations: ObservationPolicy
    public let constraints: ConstraintEvaluationPolicy
    public let admission: DynamicsAdmission
    public let mass: DynamicsSolvePolicy
    public let gapToleranceMeters: Double
    public let speedToleranceMetersPerSecond: Double
    public let minimumInverseMassPerKilogram: Double
    public let impulseScales: [Double]
    public let momentumTolerance: NumericalTolerance
    public let energyToleranceJoules: NumericalTolerance
    public init(observations: ObservationPolicy, constraints: ConstraintEvaluationPolicy, admission: DynamicsAdmission,
                mass: DynamicsSolvePolicy, gapToleranceMeters: Double, speedToleranceMetersPerSecond: Double,
                minimumInverseMassPerKilogram: Double, impulseScales: [Double],
                momentumTolerance: NumericalTolerance, energyToleranceJoules: NumericalTolerance) throws(JointStopFailure) {
        guard gapToleranceMeters.isFinite, gapToleranceMeters >= 0, speedToleranceMetersPerSecond.isFinite,
              speedToleranceMetersPerSecond >= 0, minimumInverseMassPerKilogram.isFinite, minimumInverseMassPerKilogram >= 0,
              impulseScales.allSatisfy({$0.isFinite && $0 > 0}) else { throw JointStopFailure(.invalidInput) }
        self.observations=observations; self.constraints=constraints; self.admission=admission; self.mass=mass
        self.gapToleranceMeters=gapToleranceMeters; self.speedToleranceMetersPerSecond=speedToleranceMetersPerSecond
        self.minimumInverseMassPerKilogram=minimumInverseMassPerKilogram; self.impulseScales=impulseScales
        self.momentumTolerance=momentumTolerance; self.energyToleranceJoules=energyToleranceJoules
    }
}
