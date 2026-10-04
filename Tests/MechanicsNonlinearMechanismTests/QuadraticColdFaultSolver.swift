import SwiftMechanics
import Synchronization

/// Real delegated mechanics followed by explicit ledger and cancellation faults.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class QuadraticColdFaultSolver: ConstrainedMechanismSolving, Sendable {
    enum Fault:Equatable,Sendable { case resetSuccess,resetFailure,unknown,knownFailure,lateCancellation }
    struct Evidence:Sendable { let aggregateAllowance:Int;let knownPrefix:Int;let seeds:Int }
    private let state=Mutex<Evidence?>(nil)
    private let cancelled=Mutex(false)
    private let fault:Fault
    init(_ fault:Fault) { self.fault=fault }
    func evidence() -> Evidence? { state.withLock { $0 } }
    func isCancelled() -> Bool { cancelled.withLock { $0 } }
    func reconcileVelocity(_ system:RigidDynamicsSystem,sample:VelocityConstraintSample,policy:MechanismSolvePolicy,
                           work:inout NumericalWork,dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,linearWork:inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        try MassWeightedMechanismSolver().reconcileVelocity(system,sample:sample,policy:policy,work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
    }
    func acceleration(_ system:RigidDynamicsSystem,sample:VelocityConstraintSample,drive:[Double],policy:MechanismSolvePolicy,
                      work:inout NumericalWork,dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,linearWork:inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        let allowance=work.budget.arithmeticOperations+dynamicsWork.budget.arithmeticOperations+rankWork.budget.arithmeticOperations+linearWork.budget.arithmeticOperations
        let seeds=work.operations+dynamicsWork.operations+rankWork.operations+linearWork.operations
        let result=try MassWeightedMechanismSolver().acceleration(system,sample:sample,drive:drive,policy:policy,
            work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
        if fault == .resetSuccess || fault == .resetFailure {
            do throws(NumericalError) {
                try rankWork.chargeOperations(rankWork.budget.arithmeticOperations-rankWork.operations)
                try linearWork.chargeOperations(linearWork.budget.arithmeticOperations-linearWork.operations)
            } catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
        }
        let known=dynamicsWork.operations+rankWork.operations+linearWork.operations+1
        state.withLock { $0=Evidence(aggregateAllowance:allowance,knownPrefix:known,seeds:seeds) }
        switch fault {
        case .resetSuccess:work=NumericalWork(budget:work.budget)
        case .resetFailure:work=NumericalWork(budget:work.budget);throw .cancelled
        case .unknown:throw .numerical(.invalidPolicy,failedSupplierWorkUnavailable:true)
        case .knownFailure:throw .capacityExceeded
        case .lateCancellation:cancelled.withLock { $0=true }
        }
        return result
    }
}
