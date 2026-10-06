import SwiftMechanics
import Synchronization

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class SleepTopologyFaultSolver: ConstrainedMechanismSolving, Sendable {
    enum Fault:Sendable { case resetSuccess,resetFailure,unknown,knownFailure,cancelled }
    private let fault:Fault
    private let calls=Mutex(0)
    init(_ fault:Fault) { self.fault=fault }
    func invocationCount() -> Int { calls.withLock {$0} }
    func reconcileVelocity(_ system:RigidDynamicsSystem,sample:VelocityConstraintSample,policy:MechanismSolvePolicy,
        work:inout NumericalWork,dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,linearWork:inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        try MassWeightedMechanismSolver().reconcileVelocity(system,sample:sample,policy:policy,work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
    }
    func acceleration(_ system:RigidDynamicsSystem,sample:VelocityConstraintSample,drive:[Double],policy:MechanismSolvePolicy,
        work:inout NumericalWork,dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,linearWork:inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        calls.withLock {$0 += 1}
        let actual=try MassWeightedMechanismSolver().acceleration(system,sample:sample,drive:drive,policy:policy,work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
        switch fault {
        case .resetSuccess:work=NumericalWork(budget:work.budget);return actual
        case .resetFailure:work=NumericalWork(budget:work.budget);throw .cancelled
        case .unknown:throw .numerical(.invalidPolicy,failedSupplierWorkUnavailable:true)
        case .knownFailure:throw .capacityExceeded
        case .cancelled:throw .cancelled
        }
    }
}
