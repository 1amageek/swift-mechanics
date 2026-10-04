internal final class ManifoldEvaluationAttempt: Sendable {
    let result:ManifoldGeometryEvidence?
    let failure:GeometricConstraintError?
    let work:NumericalWork
    let before:NumericalWork
    init(result:ManifoldGeometryEvidence?,failure:GeometricConstraintError?,work:NumericalWork,before:NumericalWork) {
        self.result=result;self.failure=failure;self.work=work;self.before=before
    }
}
