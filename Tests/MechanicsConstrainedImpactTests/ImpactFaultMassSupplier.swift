import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class ImpactFaultMassSupplier: RigidDynamicsSolving, Sendable {
    private let calls = Mutex(0)
    private let fault: ConstrainedImpactFault
    init(_ fault: ConstrainedImpactFault) { self.fault = fault }
    var callCount: Int { calls.withLock { $0 } }
    func inverseMassProduct(_ system: RigidDynamicsSystem, rightHandSide: [Double], policy: DynamicsSolvePolicy,
                            work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        calls.withLock { $0 += 1 }
        if fault == .failure { throw .invalidInput }
        let value = try DenseRigidDynamics().inverseMassProduct(system,rightHandSide:rightHandSide,policy:policy,work:&work)
        work = NumericalWork(budget:work.budget)
        if fault == .resetFailure { throw .invalidInput }
        if fault == .cancelled { throw .cancelled }
        return value
    }
    func forward(_ system: RigidDynamicsSystem, driveForce: [Double], policy: DynamicsSolvePolicy,
                 work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        try DenseRigidDynamics().forward(system,driveForce:driveForce,policy:policy,work:&work)
    }
    func inverse(_ system: RigidDynamicsSystem, acceleration: [Double], policy: DynamicsSolvePolicy,
                 work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        try DenseRigidDynamics().inverse(system,acceleration:acceleration,policy:policy,work:&work)
    }
    func mixed(_ system: RigidDynamicsSystem, partition: [MixedCoordinate], policy: DynamicsSolvePolicy,
               work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        try DenseRigidDynamics().mixed(system,partition:partition,policy:policy,work:&work)
    }
}
