import MechanicsNumerics
import MechanicsNonlinear
import MechanicsConstraints

internal struct StaticKKTEquations<Scalar: NumericalScalar>: NonlinearEquations {
    let model: StaticForceModel
    let constraints: QuadraticConstraintSystem?
    let independentRows: [Int]
    let branch: EquilibriumBranch
    let parameter: Scalar
    let forces: any StaticForceEvaluating<Scalar>
    let isCancelled: @Sendable () -> Bool
    var identity: String { model.identity }
    var coordinateCount: Int { model.chart.count+independentRows.count }
    func validateDomain(at point: [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        guard !isCancelled() else { throw .numerical(.cancelled) }
        guard point.count==coordinateCount else { throw .invalidEvaluation }
        do { try forces.validate(model, point: point, parameter: parameter, work: &work) } catch { throw cause(error) }
        for i in 0..<model.chart.count {
            let q=point[i]*Scalar(model.chart.scales[i])
            guard q>=Scalar(branch.minimumPosition[i]),q<=Scalar(branch.maximumPosition[i]) else { throw .equation(.outsideDomain) }
            if let c=constraints { guard q>=Scalar(c.minimumPosition[i]),q<=Scalar(c.maximumPosition[i]) else { throw .equation(.outsideDomain) } }
        }
    }
    func residual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try validateDomain(at: point, work: &work)
        guard output.count==coordinateCount else { throw .invalidEvaluation }
        let n=model.chart.count
        do { try work.chargeOperations(try NumericalWork.product(4,try NumericalWork.product(n,coordinateCount))) } catch { throw .numerical(error) }
        for i in 0..<n {
            do { output[i]=try forces.gradient(model,point: point,parameter: parameter,coordinate: i,work: &work)*Scalar(model.chart.scales[i]/model.energyScale) } catch { throw cause(error) }
            if let c=constraints { for k in independentRows.indices { output[i] += Scalar(c.rows[independentRows[k]].linear[i])*point[n+k] } }
        }
        if let c=constraints {
            for k in independentRows.indices {
                let row=c.rows[independentRows[k]]; var value=Scalar(row.constant)
                for i in 0..<n { value += Scalar(row.linear[i])*point[i] }
                output[n+k]=value
            }
        }
        guard output.allSatisfy({$0.isFinite}) else { throw .invalidEvaluation }
    }
    func originalResidual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try residual(at: point,into: &output,work: &work)
    }
    func jacobian(at point: [Scalar], into rowMajorOutput: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try validateDomain(at: point,work: &work)
        let n=model.chart.count; let d=coordinateCount
        guard rowMajorOutput.count==d*d else { throw .invalidEvaluation }
        for i in rowMajorOutput.indices { rowMajorOutput[i]=0 }
        for i in 0..<n { for j in 0..<n {
            do { rowMajorOutput[i*d+j]=try forces.tangent(model,point: point,parameter: parameter,row: i,column: j,work: &work)*Scalar(model.chart.scales[i]/model.energyScale)*Scalar(model.chart.scales[j]) } catch { throw cause(error) }
        } }
        if let c=constraints { for k in independentRows.indices { for i in 0..<n {
            let value=Scalar(c.rows[independentRows[k]].linear[i]); rowMajorOutput[i*d+n+k]=value; rowMajorOutput[(n+k)*d+i]=value
        } } }
        do { try work.chargeOperations(try NumericalWork.product(3,rowMajorOutput.count)) } catch { throw .numerical(error) }
    }
    private func cause(_ e: StaticForceError)->NonlinearCause {
        switch e { case .outsideDomain: .equation(.outsideDomain); case .numerical(let e): .numerical(e); case .invalidInput,.nonFiniteResult: .invalidEvaluation }
    }
}
