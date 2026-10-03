import MechanicsNumerics
public protocol RigidDynamicsSolving: Sendable {
    func forward(_ system: RigidDynamicsSystem, driveForce: [Double], policy: DynamicsSolvePolicy,
                 work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution
    func inverse(_ system: RigidDynamicsSystem, acceleration: [Double], policy: DynamicsSolvePolicy,
                 work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution
    func inverseMassProduct(_ system: RigidDynamicsSystem, rightHandSide: [Double], policy: DynamicsSolvePolicy,
                            work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution
    func mixed(_ system: RigidDynamicsSystem, partition: [MixedCoordinate], policy: DynamicsSolvePolicy,
               work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution
}
