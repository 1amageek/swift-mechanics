public struct GeometricPhysicalRowPolicy: Sendable {
    public let evaluation: ConstraintEvaluationPolicy
    public let maximumBodies: Int
    public let originalComparisonTolerance: Double
    public let projectionTolerance: NumericalTolerance
    public init(evaluation: ConstraintEvaluationPolicy, maximumBodies: Int,
                originalComparisonTolerance: Double, projectionTolerance: NumericalTolerance) throws(GeometricConstraintError) {
        guard maximumBodies > 0, originalComparisonTolerance.isFinite, originalComparisonTolerance >= 0 else { throw .invalidInput }
        self.evaluation = evaluation; self.maximumBodies = maximumBodies
        self.originalComparisonTolerance = originalComparisonTolerance; self.projectionTolerance = projectionTolerance
    }
}
