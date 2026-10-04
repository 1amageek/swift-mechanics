
/// Generic conformance preserves the fixed Swift 6.4 Embedded witness specialization.
internal struct ConstraintKKTEquations<Scalar: NumericalScalar>: NonlinearEquations {
    let system: QuadraticConstraintSystem
    let selected: [Int]
    let reference: [Double]
    let metric: [Double]
    let tau: Double
    let evaluationPolicy: ConstraintEvaluationPolicy
    let identity = "quadratic-constraint-local-kkt"
    var coordinateCount: Int { reference.count+selected.count }
    @inline(never)
    func validateDomain(at point: [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        guard !Task.isCancelled, !evaluationPolicy.isCancelled() else { throw .numerical(.cancelled) }
        let n=reference.count
        guard point.count == coordinateCount else { throw .invalidEvaluation }
        do { try work.chargeOperations(NumericalWork.product(n,3)) } catch { throw .numerical(error) }
        for i in 0..<n {
            let q=Double(point[i])*system.layout.scales[i]
            guard q.isFinite, q >= system.minimumPosition[i], q <= system.maximumPosition[i] else { throw .equation(.outsideDomain) }
        }
    }
    @inline(never)
    func residual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        let n=reference.count, r=selected.count
        guard output.count == n+r else { throw .invalidEvaluation }
        for i in 0..<n {
            try charge(2,&work)
            var value=Scalar(metric[i])*(point[i]-Scalar(reference[i]))
            for k in 0..<r { try charge(2,&work); value+=point[n+k]*(try gradient(system.rows[selected[k]],i:i,point:point,work:&work)) }
            guard value.isFinite else { throw .invalidEvaluation }; output[i]=value
        }
        for k in 0..<r { output[n+k]=try value(system.rows[selected[k]],point:point,work:&work) }
    }
    @inline(never)
    func originalResidual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        // Recompute from the immutable original equation records, not a cached linear model.
        try residual(at:point,into:&output,work:&work)
    }
    @inline(never)
    func jacobian(at point: [Scalar], into rowMajorOutput: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        let n=reference.count, r=selected.count, total=n+r
        guard rowMajorOutput.count == total*total else { throw .invalidEvaluation }
        for i in 0..<total { for j in 0..<total {
            try charge(1,&work)
            var entry: Scalar=0
            if i < n, j < n {
                entry=i == j ? Scalar(metric[i]) : 0
                for k in 0..<r { try charge(2,&work); entry+=point[n+k]*Scalar(system.rows[selected[k]].hessian[i*n+j]) }
            } else if i < n { entry=try gradient(system.rows[selected[j-n]],i:i,point:point,work:&work) }
            else if j < n { entry=try gradient(system.rows[selected[i-n]],i:j,point:point,work:&work) }
            guard entry.isFinite else { throw .invalidEvaluation }; rowMajorOutput[i*total+j]=entry
        } }
    }
    private func gradient(_ row: QuadraticConstraint, i: Int, point: [Scalar], work: inout NumericalWork) throws(NonlinearCause) -> Scalar {
        try charge(2,&work)
        var result=Scalar(row.linear[i])+Scalar(tau*row.mixedTime[i])
        for j in reference.indices { try charge(2,&work); result+=Scalar(row.hessian[i*reference.count+j])*point[j] }
        guard result.isFinite else { throw .invalidEvaluation }; return result
    }
    private func value(_ row: QuadraticConstraint, point: [Scalar], work: inout NumericalWork) throws(NonlinearCause) -> Scalar {
        try charge(8,&work)
        var result=Scalar(row.constant+row.timeLinear*tau+0.5*row.timeQuadratic*tau*tau)
        let n=reference.count
        for i in 0..<n {
            try charge(6,&work); result+=Scalar(row.linear[i]+tau*row.mixedTime[i])*point[i]
            for j in 0..<n { try charge(5,&work); result+=Scalar(0.5*row.hessian[i*n+j])*point[i]*point[j] }
        }
        guard result.isFinite else { throw .invalidEvaluation }; return result
    }
    private func charge(_ count: Int, _ work: inout NumericalWork) throws(NonlinearCause) {
        guard !Task.isCancelled, !evaluationPolicy.isCancelled() else { throw .numerical(.cancelled) }
        do { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
}
