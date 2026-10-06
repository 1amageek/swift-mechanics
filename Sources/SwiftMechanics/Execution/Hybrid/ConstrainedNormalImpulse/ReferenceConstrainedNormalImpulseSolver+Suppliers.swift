@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension ReferenceConstrainedNormalImpulseSolver {
    @inline(never)
    internal func inverseAction(_ source: PreparedConstrainedImpact, row: [Double], reserved: Int,
                                work: inout NumericalWork) throws(ConstrainedImpactError) -> [Double] {
        var local = try ConstrainedImpactInvocation.local(work,reserved:reserved)
        let result: DynamicsSolution
        do throws(ConstrainedImpactError) {
            result = try ConstrainedImpactInvocation.numerical(work:&local) { (nested: inout NumericalWork) throws(ConstrainedImpactError) in
                do throws(DynamicsError) { return try mass.inverseMassProduct(source.impact.system,rightHandSide:row,policy:source.policy.dynamics,work:&nested) }
                catch { throw ConstrainedImpactError(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
            }
        } catch { try ConstrainedImpactInvocation.absorb(local,into:&work,reserved:reserved); throw error }
        try ConstrainedImpactInvocation.absorb(local,into:&work,reserved:reserved)
        guard result.work == local else { throw ConstrainedImpactError(.supplierLedgerFailure,failedSupplierWorkUnavailable:true) }
        return result.acceleration
    }
    @inline(never)
    internal func linearAction(_ matrix: [Double], rhs: [Double], count: Int, source: PreparedConstrainedImpact,
                               reserved: Int, work: inout NumericalWork) throws(ConstrainedImpactError) -> [Double] {
        let value = try ConstrainedImpactArithmetic.numerical { () throws(NumericalError) in try DenseMatrix(rows:count,columns:count,values:matrix) }
        try ConstrainedImpactArithmetic.charge(1,&work)
        let budget = try ConstrainedImpactArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserved) }
        let result: LinearSolution<Double>
        do throws(NumericalError) { result = try linear.solve(value,rightHandSide:rhs,capability:source.policy.constraints.linearCapability,
                                        tolerance:source.policy.constraints.linearTolerance,budget:budget) }
        catch { throw ConstrainedImpactError(.numerical(error),failedSupplierWorkUnavailable:true) }
        let reported = result.diagnostics.work
        guard reported.budget == budget, reported.operations > 0, reported.peakScalarStorage > 0,
              result.values.count == count, result.values.allSatisfy({ $0.isFinite }) else {
            throw ConstrainedImpactError(.supplierLedgerFailure,failedSupplierWorkUnavailable:true)
        }
        try ConstrainedImpactInvocation.absorb(reported,into:&work,reserved:reserved)
        // Acceptance recomputes the original augmented equation independently of supplier diagnostics.
        for i in 0..<count {
            try ConstrainedImpactArithmetic.charge(try ConstrainedImpactArithmetic.product(2,count),&work)
            var product = 0.0, scale = abs(rhs[i])
            for j in 0..<count {
                product = try ConstrainedImpactArithmetic.finite(product+matrix[i*count+j]*result.values[j])
                scale = max(scale,abs(matrix[i*count+j]*result.values[j]))
            }
            let tolerance = source.policy.constraints.linearTolerance
            let limit = try ConstrainedImpactArithmetic.finite(tolerance.absoluteResidual+tolerance.relativeResidual*scale)
            guard abs(product-rhs[i]) <= limit else { throw ConstrainedImpactError(.residualRejected) }
        }
        return result.values
    }
    @inline(never)
    internal func originalAction(_ source: PreparedConstrainedImpact, values: [Double], reserved: Int,
                                 work: inout NumericalWork) throws(ConstrainedImpactError) -> [Double] {
        var local = try ConstrainedImpactInvocation.local(work,reserved:reserved)
        var output = [Double](repeating:0,count:values.count)
        do throws(ConstrainedImpactError) {
            try ConstrainedImpactInvocation.numerical(work:&local) { (nested: inout NumericalWork) throws(ConstrainedImpactError) in
                do throws(DynamicsError) { try equations.originalInertialForce(source.impact.system,acceleration:values,includeBias:false,into:&output,work:&nested) }
                catch { throw ConstrainedImpactError(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
            }
        } catch { try ConstrainedImpactInvocation.absorb(local,into:&work,reserved:reserved); throw error }
        try ConstrainedImpactInvocation.absorb(local,into:&work,reserved:reserved)
        guard output.count == values.count, output.allSatisfy({ $0.isFinite }) else { throw ConstrainedImpactError(.sourceMismatch) }
        return output
    }
}
