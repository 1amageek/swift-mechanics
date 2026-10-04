import SwiftMechanics
import Synchronization

/// Delegates real mechanics before spending the remaining admitted prefixes on every ledger.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class ColdAggregateSolver: ConstrainedMechanismSolving, Sendable {
    struct Evidence:Sendable {
        let arithmetic:Int
        let iterations:Int
        let delegated:Bool
    }
    private let state=Mutex<Evidence?>(nil)
    private let throwsAfterPrefix:Bool
    init(throwsAfterPrefix:Bool=false) { self.throwsAfterPrefix=throwsAfterPrefix }
    func evidence() -> Evidence? { state.withLock { $0 } }
    func reconcileVelocity(_ system:RigidDynamicsSystem,sample:VelocityConstraintSample,policy:MechanismSolvePolicy,
                           work:inout NumericalWork,dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,linearWork:inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        try MassWeightedMechanismSolver().reconcileVelocity(system,sample:sample,policy:policy,work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
    }
    func acceleration(_ system:RigidDynamicsSystem,sample:VelocityConstraintSample,drive:[Double],policy:MechanismSolvePolicy,
                      work:inout NumericalWork,dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,linearWork:inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        let arithmetic=work.budget.arithmeticOperations+dynamicsWork.budget.arithmeticOperations+rankWork.budget.arithmeticOperations+linearWork.budget.arithmeticOperations
        let iterations=work.budget.iterations+dynamicsWork.budget.iterations+rankWork.budget.iterations+linearWork.budget.iterations
        state.withLock { $0=Evidence(arithmetic:arithmetic,iterations:iterations,delegated:false) }
        let result=try MassWeightedMechanismSolver().acceleration(system,sample:sample,drive:drive,policy:policy,
            work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
        func consume(_ value:inout NumericalWork) throws(MechanismError) {
            do throws(NumericalError) {
                try value.chargeOperations(value.budget.arithmeticOperations-value.operations)
                while value.iterations < value.budget.iterations { try value.advanceIteration() }
            } catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
        }
        try consume(&work);try consume(&dynamicsWork);try consume(&rankWork);try consume(&linearWork)
        state.withLock { $0=Evidence(arithmetic:arithmetic,iterations:iterations,delegated:true) }
        if throwsAfterPrefix { throw .capacityExceeded }
        return result
    }
}
