public protocol PhysicalRigidDynamicsSolving: Sendable {
    func forward(_ system: PhysicalRigidDynamicsSystem, driveForce: [Double], policy: DynamicsSolvePolicy,
                 work: inout NumericalWork) throws(DynamicsError) -> PhysicalDynamicsSolution
    func inverse(_ system: PhysicalRigidDynamicsSystem, acceleration: [Double], policy: DynamicsSolvePolicy,
                 work: inout NumericalWork) throws(DynamicsError) -> PhysicalDynamicsSolution
    func inverseMassProduct(_ system: PhysicalRigidDynamicsSystem, rightHandSide: [Double], policy: DynamicsSolvePolicy,
                            work: inout NumericalWork) throws(DynamicsError) -> PhysicalDynamicsSolution
    func mixed(_ system: PhysicalRigidDynamicsSystem, partition: [MixedCoordinate], policy: DynamicsSolvePolicy,
               work: inout NumericalWork) throws(DynamicsError) -> PhysicalDynamicsSolution
}
