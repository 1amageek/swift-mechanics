import SwiftMechanics
import Synchronization

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class PrescribedRootAggregateSolver: PrescribedRootMechanismSolving, Sendable {
    struct Evidence:Sendable { let arithmetic:Int;let iterations:Int;let delegated:Bool;let knownPrefix:Int? }
    private let state=Mutex<Evidence?>(nil)
    private let fail:Bool
    private let reset:Bool
    init(fail:Bool,reset:Bool=false) { self.fail=fail;self.reset=reset }
    func evidence() -> Evidence? { state.withLock { $0 } }
    func reconcileVelocity(_ constraint:PrescribedRootConstraint,policy:MechanismSolvePolicy,work:inout NumericalWork,
                           dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,linearWork:inout NumericalWork) throws(MechanismError) -> PhysicalConstrainedMotion {
        try MassWeightedMechanismSolver(physicalDynamics:DenseRigidDynamics(physicalEquations:RigidEquationKernel()),physicalEquations:RigidEquationKernel())
            .reconcileVelocity(constraint,policy:policy,work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
    }
    func acceleration(_ constraint:PrescribedRootConstraint,drive:[Double],policy:MechanismSolvePolicy,work:inout NumericalWork,
                      dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,linearWork:inout NumericalWork) throws(MechanismError) -> PhysicalConstrainedMotion {
        let operations=work.budget.arithmeticOperations+dynamicsWork.budget.arithmeticOperations+rankWork.budget.arithmeticOperations+linearWork.budget.arithmeticOperations
        let iterations=work.budget.iterations+dynamicsWork.budget.iterations+rankWork.budget.iterations+linearWork.budget.iterations
        state.withLock { $0=Evidence(arithmetic:operations,iterations:iterations,delegated:false,knownPrefix:nil) }
        let result=try MassWeightedMechanismSolver(physicalDynamics:DenseRigidDynamics(physicalEquations:RigidEquationKernel()),physicalEquations:RigidEquationKernel())
            .acceleration(constraint,drive:drive,policy:policy,work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
        if reset {
            let known=1+dynamicsWork.operations+rankWork.operations+linearWork.operations
            state.withLock { $0=Evidence(arithmetic:operations,iterations:iterations,delegated:true,knownPrefix:known) }
            work=NumericalWork(budget:work.budget)
            throw .invalidInput
        }
        func consume(_ ledger:inout NumericalWork) throws(MechanismError) {
            do throws(NumericalError) {
                try ledger.chargeOperations(ledger.budget.arithmeticOperations-ledger.operations)
                while ledger.iterations < ledger.budget.iterations { try ledger.advanceIteration() }
            } catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
        }
        try consume(&work);try consume(&dynamicsWork);try consume(&rankWork);try consume(&linearWork)
        state.withLock { $0=Evidence(arithmetic:operations,iterations:iterations,delegated:true,knownPrefix:nil) }
        if fail { throw .capacityExceeded }
        return result
    }
}
