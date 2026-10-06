public protocol RollingConstraintEvaluating: Sendable {
    func evaluate(_ relation: RollingRelation, state: CompiledKinematicState,
                  prescribedPlane: RollingPrescribedPlaneSample?, policy: RollingEvaluationPolicy,
                  work: inout NumericalWork) throws(RollingError) -> RollingEvaluation
}
