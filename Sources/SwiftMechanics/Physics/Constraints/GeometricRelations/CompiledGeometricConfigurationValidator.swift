/// Strict external chart/domain admission through the actual compiled model.
public struct CompiledGeometricConfigurationValidator: GeometricConfigurationValidating, Sendable {
    public init() {}
    public func snapshot(_ system:GeometricConstraintSystem,state:KinematicState,policy:ConstraintEvaluationPolicy,
                         work:inout NumericalWork) throws(GeometricConstraintError) -> KinematicSnapshot {
        try system.snapshot(state,policy:policy,work:&work)
    }
}
