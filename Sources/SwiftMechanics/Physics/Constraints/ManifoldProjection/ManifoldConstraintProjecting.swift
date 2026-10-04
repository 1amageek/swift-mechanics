public protocol ManifoldConstraintProjecting: Sendable {
    func assemble(_ system:GeometricConstraintSystem,initial:KinematicState,policy:ManifoldProjectionPolicy,
                  work:inout NumericalWork) throws(ManifoldProjectionFailure) -> ManifoldAssemblyResult
}
