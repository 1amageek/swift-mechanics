public protocol HolonomicGeometryProviding: Sendable {
    func evaluate(_ system: GeometricConstraintSystem, state: KinematicState,
                  policy: ConstraintEvaluationPolicy, work: inout NumericalWork) throws(GeometricConstraintError) -> HolonomicGeometrySample
    func physicalRows(_ system: GeometricConstraintSystem, state: KinematicState, supplied: HolonomicGeometrySample,
                      policy: GeometricPhysicalRowPolicy, work: inout NumericalWork) throws(GeometricConstraintError) -> GeometricPhysicalRowWitness
}
