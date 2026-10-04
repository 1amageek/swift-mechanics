extension HolonomicGeometryProviding {
    /// The protocol requirement's builtin witness is source-validated, never assembled from diagnostic array shapes.
    public func physicalRows(_ system: GeometricConstraintSystem, state: KinematicState, supplied: HolonomicGeometrySample,
                             policy: GeometricPhysicalRowPolicy, work: inout NumericalWork) throws(GeometricConstraintError) -> GeometricPhysicalRowWitness {
        try GeometricPhysicalRowWitness.make(system,state:state,supplied:supplied,policy:policy,work:&work)
    }
}
