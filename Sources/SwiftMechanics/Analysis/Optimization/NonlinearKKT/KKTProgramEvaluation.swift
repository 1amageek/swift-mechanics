internal enum KKTProgramEvaluation {
    @inline(never)
    static func values<Scalar: NumericalScalar>(_ provider: any SmoothNonlinearProgramProviding<Scalar>,layout l: NonlinearProgramLayout,
        point: [Scalar],original: Bool,scratch: Int,cancelled: @Sendable () -> Bool,work: inout NumericalWork) throws(NonlinearCause) -> NonlinearProgramValues<Scalar> {
        let count=try KKTArithmetic.sum(l.variableCount,KKTArithmetic.sum(l.equalityCount,KKTArithmetic.sum(l.inequalityCount,KKTArithmetic.sum(l.equalityJacobian.columnIndices.count,l.inequalityJacobian.columnIndices.count))))
        try KKTArithmetic.charge(try KKTArithmetic.sum(1,count),work:&work,cancelled:cancelled)
        var output=NonlinearProgramValues<Scalar>(objective:.nan,gradient:[Scalar](repeating:.nan,count:l.variableCount),equalities:[Scalar](repeating:.nan,count:l.equalityCount),
            inequalities:[Scalar](repeating:.nan,count:l.inequalityCount),equalityJacobian:[Scalar](repeating:.nan,count:l.equalityJacobian.columnIndices.count),inequalityJacobian:[Scalar](repeating:.nan,count:l.inequalityJacobian.columnIndices.count))
        try KKTCallbackGate.invoke(provider,layout:l,scratch:scratch,cancelled:cancelled,work:&work) { (ledger: inout NumericalWork) throws(NonlinearCause) in
            if original { try provider.originalValues(at:point,into:&output,work:&ledger) } else { try provider.values(at:point,into:&output,work:&ledger) }
        }
        guard output.gradient.count == l.variableCount,output.equalities.count == l.equalityCount,output.inequalities.count == l.inequalityCount,
            output.equalityJacobian.count == l.equalityJacobian.columnIndices.count,output.inequalityJacobian.count == l.inequalityJacobian.columnIndices.count else { throw .invalidEvaluation }
        try KKTArithmetic.charge(try KKTArithmetic.sum(count,1),work:&work,cancelled:cancelled)
        guard output.objective.isFinite,output.gradient.allSatisfy({ $0.isFinite }),output.equalities.allSatisfy({ $0.isFinite }),output.inequalities.allSatisfy({ $0.isFinite }),
            output.equalityJacobian.allSatisfy({ $0.isFinite }),output.inequalityJacobian.allSatisfy({ $0.isFinite }) else { throw .invalidEvaluation }
        return output
    }
    @inline(never)
    static func hessian<Scalar: NumericalScalar>(_ provider: any SmoothNonlinearProgramProviding<Scalar>,layout l: NonlinearProgramLayout,point: [Scalar],
        equalities: [Scalar],inequalities: [Scalar],scratch: Int,cancelled: @Sendable () -> Bool,work: inout NumericalWork) throws(NonlinearCause) -> [Scalar] {
        let count=l.lagrangianHessian.columnIndices.count
        try KKTArithmetic.charge(count,work:&work,cancelled:cancelled)
        var output=[Scalar](repeating:.nan,count:count)
        try KKTCallbackGate.invoke(provider,layout:l,scratch:scratch,cancelled:cancelled,work:&work) { (ledger: inout NumericalWork) throws(NonlinearCause) in
            try provider.lagrangianHessian(at:point,equalityMultipliers:equalities,inequalityMultipliers:inequalities,into:&output,work:&ledger)
        }
        guard output.count == count else { throw .invalidEvaluation }
        try KKTArithmetic.charge(count,work:&work,cancelled:cancelled)
        guard output.allSatisfy({ $0.isFinite }) else { throw .invalidEvaluation }
        return output
    }
    static func coordinate<Scalar: NumericalScalar>(_ pattern: SparseOptimizationPattern,values: [Scalar],row: Int,column: Int,work: inout NumericalWork,cancelled: @Sendable () -> Bool) throws(NonlinearCause) -> Scalar {
        for k in pattern.rowOffsets[row]..<pattern.rowOffsets[row+1] { try KKTArithmetic.charge(1,work:&work,cancelled:cancelled); if pattern.columnIndices[k] == column { return values[k] } }
        return 0
    }
}
