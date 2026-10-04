public protocol HolonomicGeometryProviding: Sendable {
    func evaluate(_ system: GeometricConstraintSystem, state: KinematicState,
                  policy: ConstraintEvaluationPolicy, work: inout NumericalWork) throws(GeometricConstraintError) -> HolonomicGeometrySample
}
