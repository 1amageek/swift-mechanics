public protocol PhysicalPowerPartitioning: Sendable {
    func partitionedPower(_ system: PhysicalRigidDynamicsSystem, acceleration: [Double], knownCoordinates: [Int],
                          drive: [Double], geometricReaction: [Double], policy: DynamicsSolvePolicy,
                          work: inout NumericalWork) throws(DynamicsError) -> PartitionedMechanicalPower
}
