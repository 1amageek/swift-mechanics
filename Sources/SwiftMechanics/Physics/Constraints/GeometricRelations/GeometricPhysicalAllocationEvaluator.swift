public struct GeometricPhysicalAllocationEvaluator: GeometricPhysicalAllocationProviding {
    public init() {}
    @inline(never)
    public func physicalAllocation(_ system: GeometricConstraintSystem, state: KinematicState, supplied: GeometricPhysicalRowWitness,
                                   policy: GeometricPhysicalAllocationPolicy, work: inout NumericalWork) throws(GeometricPhysicalAllocationError) -> GeometricPhysicalAllocationWitness {
        try GeometricPhysicalAllocationWitness.make(system,state:state,supplied:supplied,policy:policy,work:&work)
    }
}
