public protocol GeometricPhysicalAllocationProviding: Sendable {
    /// Certifies reduced endpoint-wrench uniqueness conditional on a compatible known generalized reaction.
    func physicalAllocation(_ system: GeometricConstraintSystem, state: KinematicState, supplied: GeometricPhysicalRowWitness,
                            policy: GeometricPhysicalAllocationPolicy, work: inout NumericalWork) throws(GeometricPhysicalAllocationError) -> GeometricPhysicalAllocationWitness
}
