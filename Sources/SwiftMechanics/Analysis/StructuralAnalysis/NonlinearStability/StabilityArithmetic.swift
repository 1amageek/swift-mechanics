internal enum StabilityArithmetic {
    typealias Cause = NonlinearStabilityFailure.Cause
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(Cause) -> T {
        do { return try body() } catch { throw .numerical(error) }
    }
    static func force<T>(_ body: () throws(StaticForceError) -> T) throws(Cause) -> T {
        do { return try body() } catch { throw .force(error) }
    }
    static func product(_ a: Int,_ b: Int) throws(Cause) -> Int { try numerical { () throws(NumericalError) in try NumericalWork.product(a,b) } }
    static func sum(_ a: Int,_ b: Int) throws(Cause) -> Int { try numerical { () throws(NumericalError) in try NumericalWork.sum(a,b) } }
    static func charge(_ amount: Int,_ work: inout NumericalWork) throws(Cause) {
        try numerical { () throws(NumericalError) in try work.chargeOperations(amount) }
    }
    static func check(_ p: NonlinearStabilityPolicy) throws(Cause) {
        guard !p.isCancelled(),!p.equilibrium.isCancelled(),!p.evidence.isCancelled(),!p.dynamics.isCancelled() else { throw .cancelled }
        guard !p.spectrum.isCancelled() else { throw .spectral(.cancelled) }
    }
    static func prefix(_ before: NumericalWork,_ after: inout NumericalWork) throws(Cause) {
        guard before.budget==after.budget,after.operations>=before.operations,after.iterations>=before.iterations,
              after.peakScalarStorage>=before.peakScalarStorage else { after=before;throw .invalidSupplierWork }
    }
    static func norm(_ a: [Double], source: NonlinearStabilitySource) -> Double {
        var r=0.0
        for i in 0..<source.count { r=ScalarMath.norm(r,a[i]) }
        return ScalarMath.norm(r,a[source.dimension-1])
    }
    static func finite(_ a: [Double]) throws(Cause) { guard a.allSatisfy({$0.isFinite}) else { throw .nonFiniteResult } }
    @inline(never)
    static func limited(_ p: NonlinearPolicy<Double>, work: NumericalWork, reserve: Int) throws(Cause) -> NonlinearPolicy<Double> {
        try numerical { () throws(NumericalError) in
            let remaining=try work.remainingBudget(reservedStorage:reserve)
            let cap=try NumericalBudget(scalarStorage:min(remaining.scalarStorage,p.budget.scalarStorage),
                arithmeticOperations:min(remaining.arithmeticOperations,p.budget.arithmeticOperations),iterations:min(remaining.iterations,p.budget.iterations))
            return try NonlinearPolicy(strategy:p.strategy,capability:p.capability,tolerance:p.tolerance,referenceScale:p.referenceScale,
                minimumDirectionNorm:p.minimumDirectionNorm,derivativeProbeDistance:p.derivativeProbeDistance,
                derivativeAbsoluteTolerance:p.derivativeAbsoluteTolerance,derivativeRelativeTolerance:p.derivativeRelativeTolerance,
                maximumFactorEntries:p.maximumFactorEntries,estimateCondition:p.estimateCondition,budget:cap)
        }
    }
    @inline(never)
    static func solve(_ matrix: [Double], rhs: [Double], supplier: any LinearSolving<Double>,
                      policy: NonlinearStabilityPolicy, reserve: Int, work: inout NumericalWork) throws(Cause) -> [Double] {
        try check(policy)
        let m=try numerical { () throws(NumericalError) in try DenseMatrix(rows:rhs.count,columns:rhs.count,values:matrix) }
        let cap=try numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserve) }
        let result: LinearSolution<Double>
        do { result=try supplier.solve(m,rightHandSide:rhs,capability:policy.equilibrium.nonlinear.capability,
                                      tolerance:policy.equilibrium.nonlinear.tolerance,budget:cap) }
        catch { throw .linear(error) }
        guard result.diagnostics.work.budget==cap else { throw .invalidSupplierWork }
        try numerical { () throws(NumericalError) in try work.absorb(result.diagnostics.work,reservedStorage:reserve) }
        try check(policy)
        guard result.values.count==rhs.count else { throw .invalidSupplierOutput }
        try finite(result.values)
        try charge(try product(4,matrix.count),&work)
        for i in rhs.indices {
            var value=0.0;var scale=abs(rhs[i])
            for j in rhs.indices { let term=matrix[i*rhs.count+j]*result.values[j];value+=term;scale+=abs(term) }
            let t=policy.equilibrium.nonlinear.tolerance
            guard value.isFinite,scale.isFinite,abs(value-rhs[i])<=t.absoluteResidual+t.relativeResidual*scale else { throw .invalidSupplierOutput }
        }
        return result.values
    }
}
