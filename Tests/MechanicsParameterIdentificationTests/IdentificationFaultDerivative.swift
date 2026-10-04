import SwiftMechanics

struct IdentificationFaultDerivative: MechanicalDifferentiating {
    enum Mode: Sendable { case resetNumerical,resetCalls,resetAll,resetAllThenThrow,replaceLoadCancellation,refuse }
    let mode:Mode
    let didEvaluate:@Sendable () -> Void
    init(mode:Mode,didEvaluate:@escaping @Sendable () -> Void = {}) { self.mode=mode;self.didEvaluate=didEvaluate }
    func direction(_ input:MechanicalDerivativeInput,direction:MechanicalDirection,jointPolicy:JointEvaluationPolicy,
        admission:DynamicsAdmission,policy:DerivativePolicy,workspace:inout MechanicalDerivativeWorkspace,
        loadWork:inout LoadWork,supplierWork:inout DerivativeSupplierWork,work:inout NumericalWork) throws(DerivativeError) -> MechanicalTangent {
        if case .refuse=mode { throw .derivativeUnavailable }
        let result=try ExactMechanicalDifferentiator().direction(input,direction:direction,jointPolicy:jointPolicy,admission:admission,
            policy:policy,workspace:&workspace,loadWork:&loadWork,supplierWork:&supplierWork,work:&work)
        switch mode {
        case .resetNumerical: work=NumericalWork(budget:work.budget)
        case .resetCalls: supplierWork=try DerivativeSupplierWork(maximumCalls:supplierWork.maximumCalls)
        case .resetAll,.resetAllThenThrow:
            work=NumericalWork(budget:work.budget)
            supplierWork=try DerivativeSupplierWork(maximumCalls:supplierWork.maximumCalls)
            loadWork=LoadWork(budget:loadWork.budget)
            if case .resetAllThenThrow=mode { throw .callbackFailure }
        case .replaceLoadCancellation:
            let budget:LoadBudget
            do { budget=try LoadBudget(maximumWork:loadWork.budget.maximumWork,maximumScalars:loadWork.budget.maximumScalars,isCancelled:{ false }) }
            catch { throw .callbackFailure }
            var replacement=LoadWork(budget:budget)
            do { try replacement.charge(loadWork.consumed);try replacement.reserve(scalars:loadWork.peakScalars) }
            catch { throw .callbackFailure }
            loadWork=replacement
            didEvaluate()
        case .refuse: break
        }
        return result
    }
    func forwardDirection(_ input:MechanicalDerivativeInput,direction:MechanicalDirection,jointPolicy:JointEvaluationPolicy,
        admission:DynamicsAdmission,solvePolicy:DynamicsSolvePolicy,policy:DerivativePolicy,workspace:inout MechanicalDerivativeWorkspace,
        loadWork:inout LoadWork,supplierWork:inout DerivativeSupplierWork,work:inout NumericalWork) throws(DerivativeError) -> AccelerationTangent {
        throw .derivativeUnavailable
    }
    func forwardJacobian(_ input:MechanicalDerivativeInput,variable:MechanicalJacobianVariable,jointPolicy:JointEvaluationPolicy,
        admission:DynamicsAdmission,solvePolicy:DynamicsSolvePolicy,policy:DerivativePolicy,workspace:inout MechanicalDerivativeWorkspace,
        loadWork:inout LoadWork,supplierWork:inout DerivativeSupplierWork,work:inout NumericalWork) throws(DerivativeError) -> MechanicalAccelerationJacobian {
        throw .derivativeUnavailable
    }
}
