import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class ResettingPlanarFlow: PlanarFlowOperating {
    let failsAfterReset: Bool
    let calls = Mutex<Int>(0)
    let actual = ReferencePlanarFlowSolver(linear: ReferenceLinearSolver<Double>())
    init(failsAfterReset: Bool) { self.failsAfterReset = failsAfterReset }

    func project(state: PlanarState, duration: Double, policy: PlanarPolicy,
                 work: inout NumericalWork) throws(PlanarFluidError) -> PlanarProjectionResult {
        try actual.project(state: state, duration: duration, policy: policy, work: &work)
    }

    func step(state: PlanarState, source: PlanarSource, duration: Double, policy: PlanarPolicy,
              work: inout NumericalWork) throws(PlanarFluidError) -> PlanarStepResult {
        calls.withLock { $0 += 1 }
        let result = try actual.step(state: state, source: source, duration: duration, policy: policy, work: &work)
        work = NumericalWork(budget: work.budget)
        if failsAfterReset { throw .originalResidual }
        return result
    }
}
