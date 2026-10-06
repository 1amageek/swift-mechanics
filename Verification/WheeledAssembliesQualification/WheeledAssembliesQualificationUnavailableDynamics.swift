import SwiftMechanics

/// Deliberate original typed failure for the assembly's terminal ledger boundary only.
/// This fixture never issues a physical success value or claims a dynamics result.
struct WheeledAssembliesQualificationUnavailableDynamics: RigidDynamicsSolving {
    func forward(_ system: RigidDynamicsSystem, driveForce: [Double], policy: DynamicsSolvePolicy,
                 work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution { throw .supplierLedgerReplaced }
    func inverse(_ system: RigidDynamicsSystem, acceleration: [Double], policy: DynamicsSolvePolicy,
                 work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution { throw .supplierLedgerReplaced }
    func inverseMassProduct(_ system: RigidDynamicsSystem, rightHandSide: [Double], policy: DynamicsSolvePolicy,
                            work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution { throw .supplierLedgerReplaced }
    func mixed(_ system: RigidDynamicsSystem, partition: [MixedCoordinate], policy: DynamicsSolvePolicy,
               work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution { throw .supplierLedgerReplaced }
}
