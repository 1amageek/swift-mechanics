public struct ReferenceLinearQuadraticFeedback: LinearQuadraticFeedbackEvaluating, Sendable {
    public init() {}
    public func evaluate(_ design: LinearQuadraticDesign, systemIdentity: String, state: [Double], stateDimensions: [PhysicalDimension],
                         minimumInput: [Double], maximumInput: [Double], policy: LinearQuadraticPolicy,
                         work: inout NumericalWork) throws(LinearQuadraticFailure) -> LinearQuadraticCommand {
        do throws(LinearQuadraticFailure) {
            let system = design.system, n = system.stateCount, m = system.inputCount
            try LinearQuadraticArithmetic.check(policy, work: work)
            guard n <= policy.maximumStates, m <= policy.maximumInputs, state.count == n,
                  stateDimensions == system.stateDimensions, minimumInput.count == m, maximumInput.count == m else {
                throw LinearQuadraticFailure(.incompatiblePort, phase: "feedback-shape")
            }
            try LinearQuadraticArithmetic.metadata(systemIdentity, policy: policy, work: &work)
            guard systemIdentity == system.identity else { throw LinearQuadraticFailure(.provenanceMismatch, phase: "feedback-identity") }
            let storage = try LinearQuadraticArithmetic.numeric { () throws(NumericalError) in
                try NumericalWork.sum(try NumericalWork.product(8, n), try NumericalWork.sum(try NumericalWork.product(8, m),
                    try NumericalWork.sum(try NumericalWork.product(4, try NumericalWork.product(n, n)),
                        try NumericalWork.sum(try NumericalWork.product(3, try NumericalWork.product(n, m)), try NumericalWork.product(m, m)))))
            }
            if case .equilibriumBilinear(let source, _) = system.provenance {
                _ = try LinearQuadraticArithmetic.retainingSource(source, reserve: storage, policy: policy, work: &work)
            } else { try LinearQuadraticArithmetic.numeric { () throws(NumericalError) in try work.requireStorage(storage) } }
            for values in [state, minimumInput, maximumInput] { try LinearQuadraticArithmetic.finite(values, policy: policy, work: &work) }
            var normalized = [Double](repeating: 0, count: n)
            try LinearQuadraticArithmetic.charge(n, policy: policy, work: &work)
            for i in 0..<n {
                normalized[i] = state[i]/system.stateScales[i]
                guard normalized[i].isFinite else { throw LinearQuadraticFailure(.numerical(.nonFiniteResult), phase: "state-normalization") }
            }
            var unconstrained = [Double](repeating: 0, count: m), applied = unconstrained, saturated = [Bool](repeating: false, count: m)
            try LinearQuadraticArithmetic.multiply(design.feedbackGain, normalized, rows: m, inner: n, columns: 1,
                into: &unconstrained, policy: policy, work: &work)
            try LinearQuadraticArithmetic.charge(try LinearQuadraticArithmetic.size(6, m), policy: policy, work: &work)
            for i in 0..<m {
                guard minimumInput[i] <= maximumInput[i] else { throw LinearQuadraticFailure(.invalidInput, phase: "input-bounds") }
                unconstrained[i] = -unconstrained[i]*system.inputScales[i]
                guard unconstrained[i].isFinite else { throw LinearQuadraticFailure(.numerical(.nonFiniteResult), phase: "input-normalization") }
                applied[i] = min(maximumInput[i], max(minimumInput[i], unconstrained[i]))
                saturated[i] = applied[i] != unconstrained[i]
            }
            try LinearQuadraticArithmetic.check(policy, work: work)
            return LinearQuadraticCommand(systemIdentity: system.identity, samplePeriodSeconds: system.samplePeriodSeconds,
                inputDimensions: system.inputDimensions, unconstrainedInput: unconstrained, appliedInput: applied, saturated: saturated)
        } catch { throw error.retaining(work) }
    }
    public func scalarEffort(_ design: LinearQuadraticDesign, feedback: ScalarControlFeedback, sampleTimeSeconds: Double,
                             nominalEffortNewtons: Double, minimumEffortNewtons: Double, maximumEffortNewtons: Double,
                             policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) -> ScalarLinearQuadraticEffort {
        do throws(LinearQuadraticFailure) {
            try LinearQuadraticArithmetic.check(policy, work: work)
            guard case .equilibriumBilinear(let source, _) = design.system.provenance else {
                throw LinearQuadraticFailure(.provenanceMismatch, phase: "mechanical-feedback")
            }
            let chart = source.operatingPoint.model.chart, port = feedback.port
            guard design.system.stateCount == 2, design.system.inputCount == 1,
                  design.system.inputDimensions == [port.effortDimension], chart.count == 1,
                  chart.dimensions == [port.positionDimension], chart.stamp == port.binding.model,
                  chart.joints == [port.binding.joint], chart.frame == port.binding.frame,
                  source.reduction.freeCoordinates == 1, source.reduction.basis.count == 1,
                  source.operatingPoint.position.count == 1, source.reduction.basis[0].isFinite, source.reduction.basis[0] != 0,
                  sampleTimeSeconds.isFinite, sampleTimeSeconds == feedback.sourceTime,
                  nominalEffortNewtons.isFinite, minimumEffortNewtons.isFinite, maximumEffortNewtons.isFinite,
                  minimumEffortNewtons <= maximumEffortNewtons else {
                throw LinearQuadraticFailure(.incompatiblePort, phase: "mechanical-feedback")
            }
            try LinearQuadraticArithmetic.charge(12, policy: policy, work: &work)
            let basis = source.reduction.basis[0]
            let state = [(feedback.position-source.operatingPoint.position[0])/basis, feedback.rate/basis]
            let value = try evaluate(design, systemIdentity: design.system.identity, state: state,
                stateDimensions: [.dimensionless, PhysicalDimension(time: -1)],
                minimumInput: [minimumEffortNewtons-nominalEffortNewtons], maximumInput: [maximumEffortNewtons-nominalEffortNewtons],
                policy: policy, work: &work)
            let unconstrained = nominalEffortNewtons+value.unconstrainedInput[0]
            guard unconstrained.isFinite else {
                throw LinearQuadraticFailure(.numerical(.nonFiniteResult), phase: "absolute-effort")
            }
            let effort = min(maximumEffortNewtons, max(minimumEffortNewtons, unconstrained))
            let command: DriveCommand
            do { command = try DriveCommand(mode: .effort, value: effort) }
            catch { throw LinearQuadraticFailure(.invalidInput, phase: "effort-command") }
            try LinearQuadraticArithmetic.check(policy, work: work)
            return ScalarLinearQuadraticEffort(port: port, sampleTimeSeconds: sampleTimeSeconds, samplePeriodSeconds: design.system.samplePeriodSeconds,
                nominalEffortNewtons: nominalEffortNewtons, unconstrainedEffortNewtons: unconstrained, command: command, saturated: effort != unconstrained)
        } catch { throw error.retaining(work) }
    }
}
