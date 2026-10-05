import SwiftMechanics
internal struct IslandEvaluationFault: ConstraintEvaluating {
    let fail:Bool
    let opaque:Bool
    init(fail:Bool,opaque:Bool = false) { self.fail=fail;self.opaque=opaque }
    func evaluate(_ system:QuadraticConstraintSystem,position:[Double],velocity:[Double],time:Double,policy:ConstraintEvaluationPolicy,work:inout NumericalWork) throws(ConstraintError) -> ConstraintEvaluation {
        let actual=try QuadraticConstraintEvaluator().evaluate(system,position:position,velocity:velocity,time:time,policy:policy,work:&work)
        if opaque { throw .linear(.cancelled,failedSupplierWorkUnavailable:true) }
        work=NumericalWork(budget:work.budget)
        if fail { throw .cancelled };return actual
    }
}
