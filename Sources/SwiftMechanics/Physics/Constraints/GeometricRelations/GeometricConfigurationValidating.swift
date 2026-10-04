public protocol GeometricConfigurationValidating: Sendable {
    func snapshot(_ system:GeometricConstraintSystem,state:KinematicState,policy:ConstraintEvaluationPolicy,
                  work:inout NumericalWork) throws(GeometricConstraintError) -> KinematicSnapshot
}
