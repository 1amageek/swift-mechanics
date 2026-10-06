import SwiftMechanics

public enum LinearQuadraticQualificationCases {
    private typealias F = LinearQuadraticQualificationFixture
    private typealias O = LinearQuadraticQualificationOracle

    public static func analyticScalarRoots() throws {
        for values in [[1.0, 1, 1, 1, 0.5], [0.5, 2, 2, 3, 0.1]] {
            let a = values[0], b = values[1], q = values[2], r = values[3]
            let system = try F.analytic(a: [a], b: [b])
            let design = try F.design(system, q: [q], r: [r], witness: [values[4]])
            let expected = O.scalar(a: a, b: b, q: q, r: r)
            try O.array(design.riccatiMatrix, [expected.p], "Independent scalar Riccati root")
            try O.array(design.feedbackGain, [expected.k], "Independent scalar gain")
            try O.array(design.diagnostics.closedLoopLyapunovMatrix, [expected.w], "Independent scalar Lyapunov W")
            try O.require(abs(expected.f) < 1 && expected.w > 0, "Scalar Schur stability")
            try O.equations(design)
        }
    }
    public static func diagonalMatrixEquations() throws {
        let system = try F.analytic(a: [1, 0, 0, 0.5], b: [1, 0, 0, 2], states: 2, inputs: 2)
        let design = try F.design(system, q: [1, 0, 0, 2], r: [1, 0, 0, 3], witness: [0.5, 0, 0, 0.1])
        let first = O.scalar(a: 1, b: 1, q: 1, r: 1), second = O.scalar(a: 0.5, b: 2, q: 2, r: 3)
        try O.array(design.riccatiMatrix, [first.p, 0, 0, second.p], "Independent diagonal P")
        try O.array(design.feedbackGain, [first.k, 0, 0, second.k], "Independent diagonal K")
        try O.array(design.diagnostics.closedLoopLyapunovMatrix, [first.w, 0, 0, second.w], "Independent diagonal W")
        try O.equations(design)
    }
    public static func mechanicalRealizationAndDynamics() throws {
        let fixture = try LinearQuadraticQualificationMechanical()
        try O.array(fixture.source.operatingPoint.position, [0.5], "Actual equilibrium meters", physical: true)
        try O.array(fixture.source.reducedMass, [0.5], "Actual reduced mass", physical: true)
        try O.array(fixture.source.reducedStiffness, [2], "Actual reduced stiffness", physical: true)
        try O.array(fixture.source.reducedDamping, [0.5], "Actual reduced damping", physical: true)
        try O.array(fixture.source.stateMatrix, [0, 1, -4, -1], "Literal continuous state matrix", physical: true)
        try O.array(fixture.source.inputMatrix, [0, 2], "Literal parameter input", physical: true)
        try O.array(fixture.system.stateMatrix, [1.04/1.06, 0.2/1.06, -0.2/1.06, 0.94/1.06], "Calibrated bilinear A", physical: true)
        try O.array(fixture.system.inputMatrix, [0.075/1.06, 0.75/1.06], "Calibrated bilinear B", physical: true)
        guard case .equilibriumBilinear(let source, let calibration) = fixture.system.provenance else {
            throw LinearQuadraticQualificationError.assertion("Actual mechanical provenance retained")
        }
        try O.require(source.operatingPoint.model.chart.stamp == fixture.model.stamp, "Original source stamp")
        try O.close(calibration, 0.5, "Declared parameter units per newton", physical: true)
        let design = try F.design(fixture.system, q: [1, 0, 0, 1], r: [1], witness: [0, 0])
        try O.equations(design)
        let feedback = try fixture.feedback(), policy = try F.policy()
        var work = try F.work(policy)
        let evaluator: any LinearQuadraticFeedbackEvaluating = ReferenceLinearQuadraticFeedback()
        let result = try evaluator.scalarEffort(design, feedback: feedback, sampleTimeSeconds: 3, nominalEffortNewtons: 4,
            minimumEffortNewtons: -100, maximumEffortNewtons: 100, policy: policy, work: &work)
        let expected = 4-1.5*(design.feedbackGain[0]-design.feedbackGain[1])
        try O.close(result.command.value, expected, "Physical feedback effort newtons", physical: true)
        try O.require(result.command.mode == .effort && !result.saturated, "Unsaturated actual scalar effort")
        let outcome = try fixture.originalOutcome(effort: result.command.value)
        let acceleration = (expected-4.2)/2
        try O.array(outcome.solution.acceleration, [acceleration], "Actual Newton acceleration", physical: true)
        try O.close(outcome.energy.kineticEnergy, 0.01, "Actual kinetic joules", physical: true)
        try O.close(outcome.energy.kineticEnergyRate, -0.2*acceleration, "Actual kinetic power", physical: true)
        try O.close(expected*(-0.1), outcome.energy.kineticEnergyRate+8*0.55*(-0.1)+2*0.01,
            "Effort power equals kinetic/potential/dissipation rate", physical: true)
        try O.require(outcome.solution.originalPhysicalResidual.isAccepted, "Actual dynamics physical acceptance")
    }
    public static func unitsAndSaturation() throws {
        let system = try F.analytic(stateScales: [2], inputScales: [3]), design = try F.design(system)
        let policy = try F.policy(), evaluator: any LinearQuadraticFeedbackEvaluating = ReferenceLinearQuadraticFeedback()
        var work = try F.work(policy)
        let command = try evaluator.evaluate(design, systemIdentity: system.identity, state: [4], stateDimensions: [.length],
            minimumInput: [-1], maximumInput: [1], policy: policy, work: &work)
        let k = O.scalar(a: 1, b: 1, q: 1, r: 1).k
        try O.array(command.unconstrainedInput, [-6*k], "SI normalization and feedback")
        try O.array(command.appliedInput, [-1], "Explicit saturation bound")
        try O.require(command.saturated == [true] && !command.followsCertifiedLinearFeedback, "Saturation discloses certificate loss")
        let actualNextMeters = 2*(2+command.appliedInput[0]/3)
        try O.close(actualNextMeters, 10.0/3, "Applied normalized plant step")
        try O.require(abs(actualNextMeters-4*(1-k)) > 1, "Clipped plant step differs from certified pole")
        let unsaturated = try evaluator.evaluate(design, systemIdentity: system.identity, state: [0.1], stateDimensions: [.length],
            minimumInput: [-1], maximumInput: [1], policy: policy, work: &work)
        try O.require(unsaturated.followsCertifiedLinearFeedback && unsaturated.saturated == [false], "Unclipped command certificate binding")
    }
    public static func sourceAndPortRefusals() throws {
        let fixture = try LinearQuadraticQualificationMechanical(), feedback = try fixture.feedback()
        let design = try F.design(fixture.system, q: [1, 0, 0, 1], r: [1], witness: [0, 0])
        let policy = try F.policy(), evaluator: any LinearQuadraticFeedbackEvaluating = ReferenceLinearQuadraticFeedback()
        for wrongDimension in [false, true] {
            var work = try F.work(policy, seeded: true)
            do {
                _ = try evaluator.evaluate(design, systemIdentity: wrongDimension ? fixture.system.identity : "foreign-system", state: [0, 0],
                    stateDimensions: wrongDimension ? [.length, .velocity] : fixture.system.stateDimensions,
                    minimumInput: [-10], maximumInput: [10], policy: policy, work: &work)
                throw LinearQuadraticQualificationError.unexpectedSuccess("Feedback identity/dimension")
            } catch let error as LinearQuadraticFailure {
                if wrongDimension { guard case .incompatiblePort = error.cause else { throw LinearQuadraticQualificationError.unexpectedFailure(error) } }
                else { guard case .provenanceMismatch = error.cause else { throw LinearQuadraticQualificationError.unexpectedFailure(error) } }
                try known(error, work: work)
            }
        }
        var work = try F.work(policy)
        do {
            _ = try evaluator.scalarEffort(design, feedback: feedback, sampleTimeSeconds: 3.1, nominalEffortNewtons: 4,
                minimumEffortNewtons: -10, maximumEffortNewtons: 10, policy: policy, work: &work)
            throw LinearQuadraticQualificationError.unexpectedSuccess("Feedback source time")
        } catch let error as LinearQuadraticFailure {
            guard case .incompatiblePort = error.cause else { throw LinearQuadraticQualificationError.unexpectedFailure(error) }
        }
        let analytic = try F.design(F.analytic())
        do {
            _ = try evaluator.scalarEffort(analytic, feedback: feedback, sampleTimeSeconds: 3, nominalEffortNewtons: 4,
                minimumEffortNewtons: -10, maximumEffortNewtons: 10, policy: policy, work: &work)
            throw LinearQuadraticQualificationError.unexpectedSuccess("Analytic source cannot claim mechanical port")
        } catch let error as LinearQuadraticFailure {
            guard case .provenanceMismatch = error.cause else { throw LinearQuadraticQualificationError.unexpectedFailure(error) }
        }
        let preparer: any DiscreteControlSystemPreparing = ReferenceDiscreteControlSystemPreparer()
        do {
            _ = try preparer.bilinear(fixture.source, identity: "invalid-calibration", samplePeriodSeconds: 0.1, stateScales: [0.2, 0.4],
                inputDimension: .force, inputScale: 3, parameterChangePerInputUnit: 0, policy: policy, work: &work)
            throw LinearQuadraticQualificationError.unexpectedSuccess("Zero input calibration")
        } catch let error as LinearQuadraticFailure {
            guard case .invalidInput = error.cause else { throw LinearQuadraticQualificationError.unexpectedFailure(error) }
        }
    }
    public static func costAndStabilityRefusals() throws {
        let scalar = try F.analytic()
        try refuse(scalar, q: [-1], r: [1], witness: [0.5]) { if case .indefiniteStateCost = $0 { return true }; return false }
        try refuse(scalar, q: [1], r: [0], witness: [0.5]) { if case .numerical(.nonPositiveDefinite) = $0 { return true }; return false }
        let diagonal = try F.analytic(a: [0.5, 0, 0, 0.5], b: [1, 0, 0, 1], states: 2, inputs: 2)
        try refuse(diagonal, q: [1, 0.1, 0, 1], r: [1, 0, 0, 1], witness: [0, 0, 0, 0]) { if case .nonsymmetricCost = $0 { return true }; return false }
        try refuse(diagonal, q: [0, 1, 1, 0], r: [1, 0, 0, 1], witness: [0, 0, 0, 0]) { if case .indefiniteStateCost = $0 { return true }; return false }
        let uncontrollable = try F.analytic(a: [1.2], b: [0])
        try refuse(uncontrollable, q: [1], r: [1], witness: [0]) { if case .stabilizabilityWitnessRejected = $0 { return true }; return false }
        let unstable = try F.analytic(a: [1.2], b: [1])
        try refuse(unstable, q: [0], r: [1], witness: [0.5]) { if case .numerical(.nonPositiveDefinite) = $0 { return true }; return false }
        try refuse(scalar, q: [1], r: [1], witness: [0.5], policy: F.policy(riccati: 1)) { if case .nonconvergence = $0 { return true }; return false }
        try refuse(scalar, q: [], r: [1], witness: [0.5]) { if case .invalidInput = $0 { return true }; return false }
    }
    public static func cumulativeWorkAndSupplierFailures() throws {
        let system = try F.analytic(), policy = try F.policy()
        let designer: any LinearQuadraticDesigning = ReferenceLinearQuadraticDesigner()
        var work = try F.work(policy, seeded: true)
        let original = try designer.design(system, stateCost: [1], inputCost: [1], stabilizingGainWitness: [0.5], policy: policy, work: &work)
        let exactPolicy = try F.policy(operations: work.operations, storage: work.peakScalarStorage, iterations: work.iterations)
        var exactWork = try F.work(exactPolicy, seeded: true)
        let exact = try designer.design(system, stateCost: [1], inputCost: [1], stabilizingGainWitness: [0.5], policy: exactPolicy, work: &exactWork)
        try O.array(exact.riccatiMatrix, original.riccatiMatrix, "Exact resource replay P")
        try O.require(exactWork.operations == work.operations && exactWork.iterations == work.iterations &&
            exactWork.peakScalarStorage == work.peakScalarStorage && exact.diagnostics.work == exactWork, "Exact cumulative diagnostic ledger")
        for short in 0..<3 {
            let limited = try F.policy(operations: work.operations-(short == 0 ? 1 : 0), storage: work.peakScalarStorage-(short == 1 ? 1 : 0),
                iterations: work.iterations-(short == 2 ? 1 : 0))
            var attempted = try F.work(limited, seeded: true)
            do {
                _ = try designer.design(system, stateCost: [1], inputCost: [1], stabilizingGainWitness: [0.5], policy: limited, work: &attempted)
                throw LinearQuadraticQualificationError.unexpectedSuccess("One-short resource")
            } catch let error as LinearQuadraticFailure {
                guard case .numerical(.resourceLimit) = error.cause else { throw LinearQuadraticQualificationError.unexpectedFailure(error) }
                try known(error, work: attempted)
            }
        }
        for mode in [LinearQuadraticQualificationInvalidLinear.Mode.wrongValue, .wrongBudget, .failureAfterSolve] {
            var attempted = try F.work(policy, seeded: true)
            let invalid: any LinearQuadraticDesigning = ReferenceLinearQuadraticDesigner(linear: LinearQuadraticQualificationInvalidLinear(mode))
            do {
                _ = try invalid.design(system, stateCost: [1], inputCost: [1], stabilizingGainWitness: [0.5], policy: policy, work: &attempted)
                throw LinearQuadraticQualificationError.unexpectedSuccess("Invalid original solve derivative")
            } catch let error as LinearQuadraticFailure {
                switch mode {
                case .wrongValue: guard case .originalEvidenceRejected = error.cause, !error.failedSupplierWorkUnavailable else { throw LinearQuadraticQualificationError.unexpectedFailure(error) }
                case .wrongBudget: guard case .invalidSupplierLedger = error.cause, error.failedSupplierWorkUnavailable else { throw LinearQuadraticQualificationError.unexpectedFailure(error) }
                case .failureAfterSolve: guard case .numerical(.singular) = error.cause, error.failedSupplierWorkUnavailable else { throw LinearQuadraticQualificationError.unexpectedFailure(error) }
                }
                try known(error, work: attempted)
            }
        }
    }
    public static func callerAndPublicationCancellation() throws {
        let system = try F.analytic(), policy = try F.policy(cancelled: { true })
        var work = try F.work(policy, seeded: true)
        let previous = work, designer: any LinearQuadraticDesigning = ReferenceLinearQuadraticDesigner()
        do {
            _ = try designer.design(system, stateCost: [1], inputCost: [1], stabilizingGainWitness: [0.5], policy: policy, work: &work)
            throw LinearQuadraticQualificationError.unexpectedSuccess("Caller cancellation")
        } catch let error as LinearQuadraticFailure {
            guard case .cancelled = error.cause else { throw LinearQuadraticQualificationError.unexpectedFailure(error) }
            try known(error, work: work)
        }
        try O.require(work == previous, "Initial cancellation unchanged work")
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) { try finalCancellation(system) }
        else { throw LinearQuadraticQualificationError.platformUnavailable }
    }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func finalCancellation(_ system: DiscreteControlSystem) throws {
        let counter = LinearQuadraticQualificationCancellation(cancelAt: Int.max)
        let policy = try F.policy(cancelled: { counter.poll() }), designer: any LinearQuadraticDesigning = ReferenceLinearQuadraticDesigner()
        var work = try F.work(policy)
        _ = try designer.design(system, stateCost: [1], inputCost: [1], stabilizingGainWitness: [0.5], policy: policy, work: &work)
        let cancelled = LinearQuadraticQualificationCancellation(cancelAt: counter.count)
        let cancelledPolicy = try F.policy(cancelled: { cancelled.poll() })
        var cancelledWork = try F.work(cancelledPolicy)
        do {
            _ = try designer.design(system, stateCost: [1], inputCost: [1], stabilizingGainWitness: [0.5], policy: cancelledPolicy, work: &cancelledWork)
            throw LinearQuadraticQualificationError.unexpectedSuccess("Final publication cancellation")
        } catch let error as LinearQuadraticFailure {
            guard case .cancelled = error.cause else { throw LinearQuadraticQualificationError.unexpectedFailure(error) }
            try known(error, work: cancelledWork)
        }
        try O.require(cancelled.count == counter.count && cancelledWork == work, "Final cancellation retains completed original work")
    }
    public static func actualTaskCancellation(_ system: DiscreteControlSystem, policy: LinearQuadraticPolicy, work: inout NumericalWork) throws {
        let previous = work, designer: any LinearQuadraticDesigning = ReferenceLinearQuadraticDesigner()
        do {
            _ = try designer.design(system, stateCost: [1], inputCost: [1], stabilizingGainWitness: [0.5], policy: policy, work: &work)
            throw LinearQuadraticQualificationError.unexpectedSuccess("Actual cancelled Task")
        } catch let error as LinearQuadraticFailure {
            guard case .cancelled = error.cause else { throw LinearQuadraticQualificationError.unexpectedFailure(error) }
            try known(error, work: work)
        }
        try O.require(work == previous, "Cancelled Task unchanged prefix")
    }
    private static func refuse(_ system: DiscreteControlSystem, q: [Double], r: [Double], witness: [Double],
        policy: LinearQuadraticPolicy? = nil, matches: (LinearQuadraticFailure.Cause) -> Bool) throws {
        let selected: LinearQuadraticPolicy
        if let policy { selected = policy } else { selected = try F.policy() }
        var work = try F.work(selected, seeded: true)
        let designer: any LinearQuadraticDesigning = ReferenceLinearQuadraticDesigner()
        do {
            _ = try designer.design(system, stateCost: q, inputCost: r, stabilizingGainWitness: witness, policy: selected, work: &work)
            throw LinearQuadraticQualificationError.unexpectedSuccess("Typed design refusal")
        } catch let error as LinearQuadraticFailure {
            try O.require(matches(error.cause), "Expected original typed design cause")
            try known(error, work: work)
        }
    }
    private static func known(_ failure: LinearQuadraticFailure, work: NumericalWork) throws {
        guard let recorded = failure.knownWork else { throw LinearQuadraticQualificationError.assertion("Missing known caller work") }
        try O.require(recorded == work, "Failure records actual caller ledger")
    }
}
