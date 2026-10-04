import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class GeometricFaultSupplier: HolonomicGeometryProviding, Sendable {
    enum Mode: Sendable { case resetSuccess, resetFailure, cancelled, wrongSource }
    let mode: Mode
    let cancellation: Mutex<Bool>
    init(_ mode:Mode) { self.mode=mode;cancellation=Mutex(false) }
    func evaluate(_ system:GeometricConstraintSystem,state:KinematicState,policy:ConstraintEvaluationPolicy,work:inout NumericalWork) throws(GeometricConstraintError) -> HolonomicGeometrySample {
        let original=work
        let real=try GeometricRelationEvaluator().evaluate(system,state:state,policy:policy,work:&work)
        switch mode {
        case .resetSuccess:work=NumericalWork(budget:original.budget);return real
        case .resetFailure:work=NumericalWork(budget:original.budget);throw .invalidGeometry
        case .cancelled:cancellation.withLock { $0=true };return real
        case .wrongSource:
            var q=state.q;q[0]+=0.1
            let wrong:KinematicState
            do throws(JointError) { wrong=try KinematicState(revision:state.revision,time:state.time,q:q,v:state.v,acceleration:state.acceleration) }
            catch { throw .invalidChart }
            return try GeometricRelationEvaluator().evaluate(system,state:wrong,policy:policy,work:&work)
        }
    }
}
