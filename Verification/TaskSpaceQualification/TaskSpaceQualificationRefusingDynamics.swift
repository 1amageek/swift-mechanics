import SwiftMechanics

/// Failure witnesses never replace a successful original physical solve.
public struct TaskSpaceQualificationRefusingDynamics: PhysicalRigidDynamicsSolving, Sendable {
    public enum Mode: Sendable { case chargeThenRefuse, resetThenRefuse }
    public let mode: Mode
    public init(mode: Mode) { self.mode = mode }
    public func forward(_ system: PhysicalRigidDynamicsSystem, driveForce: [Double], policy: DynamicsSolvePolicy,
                        work: inout NumericalWork) throws(DynamicsError) -> PhysicalDynamicsSolution {
        try DenseRigidDynamics().forward(system, driveForce: driveForce, policy: policy, work: &work)
    }
    public func inverse(_ system: PhysicalRigidDynamicsSystem, acceleration: [Double], policy: DynamicsSolvePolicy,
                        work: inout NumericalWork) throws(DynamicsError) -> PhysicalDynamicsSolution {
        try DenseRigidDynamics().inverse(system, acceleration: acceleration, policy: policy, work: &work)
    }
    public func mixed(_ system: PhysicalRigidDynamicsSystem, partition: [MixedCoordinate], policy: DynamicsSolvePolicy,
                      work: inout NumericalWork) throws(DynamicsError) -> PhysicalDynamicsSolution {
        try DenseRigidDynamics().mixed(system, partition: partition, policy: policy, work: &work)
    }
    public func inverseMassProduct(_ system: PhysicalRigidDynamicsSystem, rightHandSide: [Double], policy: DynamicsSolvePolicy,
                                   work: inout NumericalWork) throws(DynamicsError) -> PhysicalDynamicsSolution {
        switch mode {
        case .chargeThenRefuse:
            do throws(NumericalError) { try work.chargeOperations(13) }
            catch { throw .numerical(error, failedSupplierWorkUnavailable: false) }
        case .resetThenRefuse: work = NumericalWork(budget: work.budget)
        }
        throw .cancelled
    }
}
