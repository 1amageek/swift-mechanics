import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints
import MechanicsCompiler
import MechanicsRuntime
import MechanicsFluids

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    static func verifyFluids() throws {
        let context = try FluidProbeContext()
        defer { _ = context.session.shutdown() }
        for i in 0..<4 { try require(abs(context.initial.velocities[i] - (Double(i) + 0.5) / 4) < 1e-10) }
        try require(abs(context.initial.pressureFaces[4] + 19.62) < 1e-9)
        let prefix = context.session.snapshot()
        _ = try fluidProbeAdvance(context, decision: .reject, budget: context.budget)
        try require(context.session.snapshot() == prefix)
        let accepted = try fluidProbeAdvance(context, decision: .accept, budget: context.budget)
        let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        let checkpoint = try context.session.checkpoint(codec: codec)
        var bytes = try FluidByteWork(maximumBytes: 8192, maximumVisitedBytes: 8192)
        let state = try context.codec.decode(accepted.checkpoint.contributors[0], work: &bytes)
        try require(state.time == 0.1 && state.sequence == 1 && state.velocities[3] < context.initial.velocities[3])
        let after = try fluidProbeAdvance(context, decision: .accept, budget: context.budget)
        _ = try context.session.restart(checkpoint, codec: codec)
        let replay = try fluidProbeAdvance(context, decision: .accept, budget: context.budget)
        try require(replay == after && accepted.physical.state.q.isEmpty && accepted.physical.state.v.isEmpty)
        let retained = context.session.snapshot()
        var failed = false
        let limited = try NumericalBudget(scalarStorage: 100000, arithmeticOperations: 1000000, iterations: 0)
        do throws(RuntimeFailure) { _ = try fluidProbeAdvance(context, decision: .accept, budget: limited) }
        catch { try require(error.failedSupplierWorkUnavailable && error.lastAccepted == retained); failed = true }
        try require(failed && context.session.snapshot() == retained)
    }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func fluidProbeAdvance(_ context: FluidProbeContext, decision: RuntimeTrialDecision,
                                          budget: NumericalBudget) throws(RuntimeFailure) -> RuntimeAcceptedState {
        let boundary: FluidBoundary
        do throws(FluidError) { boundary = try FluidBoundary(lowerSpeed: 0, upperSpeed: 0, pressureGradientX: 0, lowerGaugePressure: 0) }
        catch { throw RuntimeFailure(.invalidInput, message: "Probe boundary construction failed.") }
        let outcome = try context.session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            var work = NumericalWork(budget: budget), bytes: FluidByteWork
            do throws(FluidError) { bytes = try FluidByteWork(maximumBytes: 8192, maximumVisitedBytes: 8192) }
            catch { throw RuntimeFailure(.invalidInput, message: "Probe byte work construction failed.") }
            let operation: any FluidTrialOperating = context.operation
            let value = try operation.advance(model: context.model, boundary: boundary, duration: 0.1, policy: context.policy,
                trial: &trial, control: &control, numerical: &work, bytes: &bytes)
            guard let defect = value.balance.energyDefect, abs(defect) < 1e-9, value.balance.numericalDissipation >= 0,
                  value.balance.viscousPower >= 0, value.balance.maximumMomentumResidual < 1e-9 else {
                throw RuntimeFailure(.invalidState, message: "Actual fluid momentum/energy balance failed.")
            }
            return decision
        }
        return outcome.accepted
    }
}
