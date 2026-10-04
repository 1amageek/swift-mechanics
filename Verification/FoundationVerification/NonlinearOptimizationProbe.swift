import SwiftMechanics

/// Analytic normalized objective and curved equality, independent of optimizer output.
struct NonlinearOptimizationProbe<Scalar: NumericalScalar>: SmoothNonlinearProgramProviding, Sendable {
    let layout: NonlinearProgramLayout
    let negativeCurvature: Bool

    init(layout: NonlinearProgramLayout, negativeCurvature: Bool = false) {
        self.layout = layout; self.negativeCurvature = negativeCurvature
    }

    func validateDomain(at point: [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try charge(8, work: &work)
        guard point.count == 2 else { throw .invalidEvaluation }
        guard point[0].isFinite, point[1].isFinite,
              point[0] >= Scalar(-10), point[0] <= Scalar(10),
              point[1] >= Scalar(-10), point[1] <= Scalar(10) else { throw .equation(.outsideDomain) }
    }

    @inline(never)
    func values(at point: [Scalar], into output: inout NonlinearProgramValues<Scalar>,
                work: inout NumericalWork) throws(NonlinearCause) {
        try evaluate(point, into: &output, work: &work)
    }

    @inline(never)
    func originalValues(at point: [Scalar], into output: inout NonlinearProgramValues<Scalar>,
                        work: inout NumericalWork) throws(NonlinearCause) {
        // Every invocation recomputes the original formulas; no solver result or cached value is consumed.
        try evaluate(point, into: &output, work: &work)
    }

    @inline(never)
    private func evaluate(_ point: [Scalar], into output: inout NonlinearProgramValues<Scalar>,
                          work: inout NumericalWork) throws(NonlinearCause) {
        try validateDomain(at: point, work: &work)
        guard layout.variableCount == 2, layout.equalityCount == 1, layout.inequalityCount == 0,
              output.gradient.count == 2, output.equalities.count == 1, output.inequalities.isEmpty,
              output.equalityJacobian.count == 2, output.inequalityJacobian.isEmpty else { throw .invalidEvaluation }
        try charge(24, work: &work)
        let x = point[0], y = point[1], difference = x-Scalar(3)
        let sign: Scalar = negativeCurvature ? -1 : 1
        output.objective = sign*(difference*difference+y*y)/Scalar(2)
        output.gradient[0] = sign*difference; output.gradient[1] = sign*y
        output.equalities[0] = x*x-y
        output.equalityJacobian[0] = Scalar(2)*x; output.equalityJacobian[1] = -1
        guard output.objective.isFinite, output.gradient[0].isFinite, output.gradient[1].isFinite,
              output.equalities[0].isFinite, output.equalityJacobian[0].isFinite else { throw .invalidEvaluation }
    }

    @inline(never)
    func lagrangianHessian(at point: [Scalar], equalityMultipliers: [Scalar], inequalityMultipliers: [Scalar],
                           into sparseValues: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try validateDomain(at: point, work: &work)
        guard equalityMultipliers.count == 1, inequalityMultipliers.isEmpty,
              equalityMultipliers[0].isFinite, sparseValues.count == 2 else { throw .invalidEvaluation }
        try charge(8, work: &work)
        let sign: Scalar = negativeCurvature ? -1 : 1
        // H_f = sign*I, H_(x^2-y) = diag(2,0); the constraint stress term is required.
        sparseValues[0] = sign+Scalar(2)*equalityMultipliers[0]
        sparseValues[1] = sign
        guard sparseValues[0].isFinite else { throw .invalidEvaluation }
    }

    private func charge(_ operations: Int, work: inout NumericalWork) throws(NonlinearCause) {
        do throws(NumericalError) {
            try work.requireStorage(8)
            try work.chargeOperations(operations)
        } catch { throw .numerical(error) }
    }
}
