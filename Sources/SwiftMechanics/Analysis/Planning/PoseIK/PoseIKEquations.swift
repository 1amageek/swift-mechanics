internal struct PoseIKEquations: NonlinearEquations, Sendable {
    typealias Scalar = Double
    let admission: PoseIKAdmission
    var identity: String { admission.problem.identity }
    var coordinateCount: Int { admission.solverCount }

    func validateDomain(at point: [Double], work: inout NumericalWork) throws(NonlinearCause) {
        do throws(PoseIKError) {
            guard point.count == coordinateCount, point.allSatisfy({ $0.isFinite }) else { throw .invalidShape }
            _ = try admission.state(point, work: &work)
        } catch { throw PoseIKArithmetic.bridge(error) }
    }
    func residual(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        do { try values(point, original: false, into: &output, work: &work) }
        catch { throw PoseIKArithmetic.bridge(error) }
    }
    func originalResidual(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        do { try values(point, original: true, into: &output, work: &work) }
        catch { throw PoseIKArithmetic.bridge(error) }
    }
    private func values(_ point: [Double], original: Bool, into output: inout [Double], work: inout NumericalWork) throws(PoseIKError) {
        guard output.count == coordinateCount, point.count == coordinateCount else { throw .invalidShape }
        let n = admission.problem.layout.scales.count, m = admission.rows.count
        let sample = try PoseIKTaskEvaluator(admission: admission).evaluate(point, original: original, work: &work)
        try PoseIKArithmetic.charge(try PoseIKArithmetic.product(4, try PoseIKArithmetic.product(n,m+1)), &work)
        for i in 0..<n {
            var value = point[i]-admission.problem.referencePositions[i]/admission.problem.layout.scales[i]
            for r in 0..<m { value += sample.jacobian[r*n+i]*point[n+r] }
            output[i] = try PoseIKArithmetic.finite(value)
        }
        for r in 0..<m { output[n+r] = sample.values[r] }
    }
    @inline(never)
    func jacobian(at point: [Double], into rowMajorOutput: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        do throws(PoseIKError) {
            let n = admission.problem.layout.scales.count, m = admission.rows.count, d = coordinateCount
            guard point.count == d, rowMajorOutput.count == (try PoseIKArithmetic.product(d,d)) else { throw .invalidShape }
            let sample = try PoseIKTaskEvaluator(admission: admission).evaluate(point, original: false, work: &work)
            try PoseIKArithmetic.charge(try PoseIKArithmetic.product(4, try PoseIKArithmetic.product(d,d)), &work)
            for i in rowMajorOutput.indices { rowMajorOutput[i] = 0 }
            for i in 0..<n { rowMajorOutput[i*d+i] = 1 }
            for r in 0..<m { for i in 0..<n {
                rowMajorOutput[i*d+n+r] = sample.jacobian[r*n+i]
                rowMajorOutput[(n+r)*d+i] = sample.jacobian[r*n+i]
            } }
            try PoseIKHessianAssembler(admission: admission).add(sample, multipliers: point[n..<d], into: &rowMajorOutput, work: &work)
            guard rowMajorOutput.allSatisfy({ $0.isFinite }) else { throw .nonFiniteResult }
            try PoseIKArithmetic.check(admission.policy)
        } catch { throw PoseIKArithmetic.bridge(error) }
    }
}
