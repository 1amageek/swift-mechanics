
public struct JointEvaluationPolicy: Equatable, Sendable {
    public let quaternionTolerance: NumericalTolerance
    public let chartRankRelative: Double
    public let characteristicLengthMeters: Double

    public init(quaternionTolerance: NumericalTolerance, chartRankRelative: Double,
                characteristicLengthMeters: Double) throws(JointError) {
        guard chartRankRelative.isFinite, chartRankRelative >= 0, chartRankRelative < 1,
              characteristicLengthMeters.isFinite, characteristicLengthMeters > 0 else { throw .invalidPolicy }
        self.quaternionTolerance = quaternionTolerance
        self.chartRankRelative = chartRankRelative
        self.characteristicLengthMeters = characteristicLengthMeters
    }
}
