import SwiftMechanics

struct IdentificationFaultOptimizer: OptimizationSolving {
    enum Mode: Sendable { case differentObjective,resetLedger }
    let mode:Mode
    func solve(_ p:ConvexOptimizationProblem,policy:OptimizationPolicy,workspace:inout EnumerationWorkspace,
               work:inout NumericalWork) throws(OptimizationFailure) -> OptimizationResult {
        let program:ConvexOptimizationProblem
        switch mode {
        case .differentObjective:
            program=ConvexOptimizationProblem(metadata:p.metadata,linearCost:[0,0],constantCost:0,hessian:p.hessian,
                lowerBounds:p.lowerBounds,upperBounds:p.upperBounds)
        case .resetLedger: program=p
        }
        let result=try CompleteConvexOptimizer().solve(program,policy:policy,workspace:&workspace,work:&work)
        if case .resetLedger=mode { work=NumericalWork(budget:work.budget) }
        return result
    }
}
