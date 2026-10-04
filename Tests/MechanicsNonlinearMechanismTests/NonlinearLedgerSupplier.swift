import SwiftMechanics

internal struct NonlinearLedgerSupplier: ConstraintEvaluating, Sendable {
    let fails: Bool
    var resets: Bool = true
    func evaluate(_ system:QuadraticConstraintSystem,position:[Double],velocity:[Double],time:Double,
                  policy:ConstraintEvaluationPolicy,work:inout NumericalWork) throws(ConstraintError) -> ConstraintEvaluation {
        let result=try QuadraticConstraintEvaluator().evaluate(system,position:position,velocity:velocity,time:time,policy:policy,work:&work)
        if time >= 0.075 {
            if resets { work=NumericalWork(budget:work.budget) }
            if fails { throw .cancelled }
        }
        return result
    }
}
