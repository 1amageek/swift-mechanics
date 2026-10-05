public struct ArticulatedDynamicsPolicy: Sendable {
    public let admission: DynamicsAdmission
    public let coordinateScales: [Double]
    public let energyScale: Double
    public let timeScale: Double
    public let pivotThreshold: Double
    public let originalResidualTolerance: NumericalTolerance
    public let powerTolerance: NumericalTolerance
    public let angularMomentumReferenceWorld: Vector3
    public let requireCompleteEnergy: Bool
    public init(admission: DynamicsAdmission, coordinateScales: [Double], energyScale: Double, timeScale: Double,
                pivotThreshold: Double, originalResidualTolerance: NumericalTolerance, powerTolerance: NumericalTolerance,
                angularMomentumReferenceWorld: Vector3 = .zero, requireCompleteEnergy: Bool = false) throws(ArticulatedDynamicsFailure) {
        guard coordinateScales.allSatisfy({$0.isFinite && $0 > 0}), energyScale.isFinite, energyScale > 0,
              timeScale.isFinite, timeScale > 0, (timeScale*timeScale).isFinite, timeScale*timeScale > 0,
              pivotThreshold.isFinite, pivotThreshold >= 0 else { throw ArticulatedDynamicsFailure(.invalidInput) }
        for scale in coordinateScales {
            guard (scale/energyScale).isFinite, scale/energyScale > 0,
                  (scale/(timeScale*timeScale)).isFinite, scale/(timeScale*timeScale) > 0 else {
                throw ArticulatedDynamicsFailure(.invalidInput)
            }
        }
        self.admission = admission; self.coordinateScales = coordinateScales; self.energyScale = energyScale
        self.timeScale = timeScale; self.pivotThreshold = pivotThreshold; self.originalResidualTolerance = originalResidualTolerance
        self.powerTolerance = powerTolerance; self.angularMomentumReferenceWorld = angularMomentumReferenceWorld
        self.requireCompleteEnergy = requireCompleteEnergy
    }
}
