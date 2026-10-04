import SwiftMechanics

/// Fault injection returns a real sealed witness from another source without fabricating its fields.
internal struct AllocationReturningSupplier: GeometricPhysicalAllocationProviding {
    let witness: GeometricPhysicalAllocationWitness
    func physicalAllocation(_ system:GeometricConstraintSystem,state:KinematicState,supplied:GeometricPhysicalRowWitness,
                            policy:GeometricPhysicalAllocationPolicy,work:inout NumericalWork) throws(GeometricPhysicalAllocationError)->GeometricPhysicalAllocationWitness {
        witness
    }
}
