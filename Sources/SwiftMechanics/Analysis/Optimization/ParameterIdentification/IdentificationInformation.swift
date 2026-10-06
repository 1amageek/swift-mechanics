internal enum IdentificationInformation {
    @inline(never)
    static func covariance(_ information:[Double],references:[SIReferenceQuantity<Double>],solver:any LinearSolving<Double>,
        policy:IdentificationPolicy,context:inout IdentificationContext,work:inout NumericalWork) throws(IdentificationCause) -> ([Double],Double) {
        do { try policy.informationCapability.validate(for:Double.self,algorithms:[.cholesky]) } catch { throw .numerical(error) }
        let matrix:DenseMatrix<Double>
        do { matrix=try DenseMatrix(rows:2,columns:2,values:information) } catch { throw .numerical(error) }
        try IdentificationArithmetic.charge(8,policy,&work)
        var inverse=[Double](repeating:0,count:4)
        for column in 0..<2 {
            try IdentificationArithmetic.check(policy)
            let budget:NumericalBudget
            do { budget=try work.remainingBudget(reservedStorage:context.reserved) } catch { throw .numerical(error) }
            let result:LinearSolution<Double>
            do { result=try solver.solve(matrix,rightHandSide:column == 0 ? [1,0] : [0,1],capability:policy.informationCapability,tolerance:policy.informationTolerance,budget:budget) }
            catch { context.unavailable=true;throw .numerical(error) }
            guard result.diagnostics.work.budget == budget else { context.unavailable=true;throw .invalidSupplierLedger }
            try IdentificationArithmetic.absorb(result.diagnostics.work,reserved:context.reserved,&work)
            guard result.values.count == 2,result.values[0].isFinite,result.values[1].isFinite,
                  result.diagnostics.numericalRank == 2,result.diagnostics.capability == policy.informationCapability,
                  result.diagnostics.factorization == .cholesky,result.diagnostics.originalResidual.isAccepted else { throw .invalidSupplierOutput }
            inverse[column]=result.values[0];inverse[2+column]=result.values[1]
        }
        var residual=0.0
        for i in 0..<2 { for j in 0..<2 {
            try IdentificationArithmetic.charge(8,policy,&work)
            let actual=try IdentificationArithmetic.finite(information[2*i]*inverse[j]+information[2*i+1]*inverse[2+j])
            let expected=i == j ? 1.0 : 0.0
            residual=max(residual,abs(actual-expected))
            guard try IdentificationArithmetic.agrees(actual,expected,policy.informationAgreement) else { throw .originalEvidenceRejected }
        } }
        for i in 0..<2 { for j in 0..<2 {
            try IdentificationArithmetic.charge(2,policy,&work)
            inverse[2*i+j]=try IdentificationArithmetic.finite(inverse[2*i+j]*references[i].magnitude*references[j].magnitude)
        } }
        return (inverse,residual)
    }
}
