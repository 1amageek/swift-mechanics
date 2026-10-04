internal struct FixedActiveKKTEquations<Scalar: NumericalScalar>: NonlinearEquations, Sendable {
    let provider: any SmoothNonlinearProgramProviding<Scalar>, layout: NonlinearProgramLayout
    let lower: [Scalar],upper: [Scalar],active: [Int],scratch: Int,cancelled: @Sendable () -> Bool
    var identity: String { "fixed-active-kkt" }
    var coordinateCount: Int { layout.variableCount+layout.equalityCount+active.count }
    func validateDomain(at point: [Scalar],work: inout NumericalWork) throws(NonlinearCause) {
        let x=try primal(point,work:&work)
        try KKTCallbackGate.invoke(provider,layout:layout,scratch:scratch,cancelled:cancelled,work:&work) { (ledger: inout NumericalWork) throws(NonlinearCause) in try provider.validateDomain(at:x,work:&ledger) }
    }
    func residual(at point: [Scalar],into output: inout [Scalar],work: inout NumericalWork) throws(NonlinearCause) { try evaluate(point,output:&output,original:false,work:&work) }
    func originalResidual(at point: [Scalar],into output: inout [Scalar],work: inout NumericalWork) throws(NonlinearCause) { try evaluate(point,output:&output,original:true,work:&work) }
    @inline(never)
    private func evaluate(_ z: [Scalar],output: inout [Scalar],original: Bool,work: inout NumericalWork) throws(NonlinearCause) {
        guard output.count == coordinateCount else { throw .invalidEvaluation }
        let n=layout.variableCount,r=layout.equalityCount,x=try primal(z,work:&work)
        let v=try KKTProgramEvaluation.values(provider,layout:layout,point:x,original:original,scratch:scratch,cancelled:cancelled,work:&work)
        try KKTArithmetic.charge(try KKTArithmetic.sum(coordinateCount,KKTArithmetic.product(2,KKTArithmetic.product(n,r+active.count))),work:&work,cancelled:cancelled)
        for j in 0..<n {
            var value=v.gradient[j]
            for i in 0..<r { value=try KKTArithmetic.finite(value+coefficient(v,equality:i,column:j,work:&work)*z[n+i]) }
            for i in active.indices { value=try KKTArithmetic.finite(value+inequalityCoefficient(v,index:active[i],column:j,work:&work)*z[n+r+i]) }
            output[j]=value
        }
        for i in 0..<r { output[n+i]=v.equalities[i] }
        for i in active.indices { output[n+r+i]=inequalityValue(v,point:x,index:active[i]) }
    }
    @inline(never)
    func jacobian(at z: [Scalar],into output: inout [Scalar],work: inout NumericalWork) throws(NonlinearCause) {
        let n=layout.variableCount,r=layout.equalityCount,d=coordinateCount
        guard output.count == (try KKTArithmetic.product(d,d)) else { throw .invalidEvaluation }
        let x=try primal(z,work:&work)
        let v=try KKTProgramEvaluation.values(provider,layout:layout,point:x,original:false,scratch:scratch,cancelled:cancelled,work:&work)
        let dual=try multipliers(z,work:&work)
        let h=try KKTProgramEvaluation.hessian(provider,layout:layout,point:x,equalities:dual.0,inequalities:dual.1,scratch:scratch,cancelled:cancelled,work:&work)
        try KKTArithmetic.charge(try KKTArithmetic.sum(KKTArithmetic.product(d,d),KKTArithmetic.product(4,KKTArithmetic.product(n,r+active.count))),work:&work,cancelled:cancelled)
        for i in output.indices { output[i]=0 }
        for i in 0..<n { for k in layout.lagrangianHessian.rowOffsets[i]..<layout.lagrangianHessian.rowOffsets[i+1] { output[i*d+layout.lagrangianHessian.columnIndices[k]]=h[k] } }
        for i in 0..<(r+active.count) { for j in 0..<n {
            let c=try i < r ? coefficient(v,equality:i,column:j,work:&work) : inequalityCoefficient(v,index:active[i-r],column:j,work:&work)
            output[(n+i)*d+j]=c; output[j*d+n+i]=c
        } }
    }
    func primal(_ z: [Scalar],work: inout NumericalWork) throws(NonlinearCause) -> [Scalar] {
        guard z.count == coordinateCount else { throw .invalidEvaluation }
        try KKTArithmetic.charge(z.count+layout.variableCount,work:&work,cancelled:cancelled)
        guard z.allSatisfy({ $0.isFinite }) else { throw .invalidEvaluation }
        // Bounded API adaptation copy: the supplier owns z, while the physical callback consumes x only.
        var x=[Scalar](repeating:0,count:layout.variableCount)
        for i in x.indices { x[i]=z[i] }
        return x
    }
    func multipliers(_ z: [Scalar],work: inout NumericalWork) throws(NonlinearCause) -> ([Scalar],[Scalar]) {
        let n=layout.variableCount,r=layout.equalityCount,m=layout.inequalityCount
        try KKTArithmetic.charge(r+m+active.count,work:&work,cancelled:cancelled)
        var e=[Scalar](repeating:0,count:r),g=[Scalar](repeating:0,count:m)
        for i in 0..<r { e[i]=z[n+i] }
        for i in active.indices { if active[i] < m { g[active[i]]=z[n+r+i] } }
        return (e,g)
    }
    func coefficient(_ v: NonlinearProgramValues<Scalar>,equality i: Int,column j: Int,work: inout NumericalWork) throws(NonlinearCause) -> Scalar { try KKTProgramEvaluation.coordinate(layout.equalityJacobian,values:v.equalityJacobian,row:i,column:j,work:&work,cancelled:cancelled) }
    func inequalityCoefficient(_ v: NonlinearProgramValues<Scalar>,index i: Int,column j: Int,work: inout NumericalWork) throws(NonlinearCause) -> Scalar {
        let m=layout.inequalityCount
        if i < m { return try KKTProgramEvaluation.coordinate(layout.inequalityJacobian,values:v.inequalityJacobian,row:i,column:j,work:&work,cancelled:cancelled) }
        let k=(i-m)/2
        return k == j ? ((i-m)%2 == 0 ? -1 : 1) : 0
    }
    func inequalityValue(_ v: NonlinearProgramValues<Scalar>,point x: [Scalar],index i: Int) -> Scalar {
        let m=layout.inequalityCount
        if i < m { return v.inequalities[i] }
        let k=(i-m)/2
        return (i-m)%2 == 0 ? lower[k]-x[k] : x[k]-upper[k]
    }
}
