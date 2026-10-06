import SwiftMechanics

struct SensorFaultSourcePreparer: ObservationSourcePreparing {
    enum Fault: Equatable, Sendable { case stale, ledger, unavailable }
    let fault: Fault
    func prepare(model: CompiledMechanicalModel, state: CompiledKinematicState, solved: ConstrainedMotion?,
                 policy: ObservationPolicy, work: inout NumericalWork) throws(ObservationError) -> ObservationSource {
        if state.state.time > 0 {
            if fault == .unavailable { throw .frameSupplierFailure }
            if fault == .ledger {
                let result = try ReferenceObservationSourcePreparer().prepare(model: model, state: state, solved: solved, policy: policy, work: &work)
                work = NumericalWork(budget: work.budget); return result
            }
            let initial: CompiledKinematicState
            do { initial = try model.makeState(model.descriptor.initialState) } catch { throw .staleSource }
            return try ReferenceObservationSourcePreparer().prepare(model: model, state: initial, policy: policy, work: &work)
        }
        return try ReferenceObservationSourcePreparer().prepare(model: model, state: state, solved: solved, policy: policy, work: &work)
    }
}
