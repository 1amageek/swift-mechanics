import SwiftMechanics

internal struct GeometricEvolutionSupplier: HolonomicGeometryProviding, Sendable {
    enum Fault: Sendable { case resetSuccess, resetFailure, cancel, source }
    let fault:Fault
    func evaluate(_ system:GeometricConstraintSystem,state:KinematicState,policy:ConstraintEvaluationPolicy,
                  work:inout NumericalWork) throws(GeometricConstraintError) -> HolonomicGeometrySample {
        let source:KinematicState
        if case .source=fault {
            var q=state.q;q[0]+=0.01
            do throws(JointError) { source=try KinematicState(revision:state.revision,time:state.time,q:q,v:state.v,acceleration:state.acceleration) }
            catch { throw .invalidChart }
        } else { source=state }
        let result=try GeometricRelationEvaluator().evaluate(system,state:source,policy:policy,work:&work)
        if state.time >= 0.075 {
            switch fault {
            case .resetSuccess: work=NumericalWork(budget:work.budget)
            case .resetFailure: work=NumericalWork(budget:work.budget);throw .cancelled
            case .cancel: throw .cancelled
            case .source: break
            }
        }
        return result
    }
}
