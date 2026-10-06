internal struct StabilityArcEquations: NonlinearEquations, Sendable {
    let source: NonlinearStabilitySource
    let policy: NonlinearStabilityPolicy
    let forces: any StaticForceEvaluating<Double>
    let predictor: [Double]
    let direction: [Double]
    var identity: String { source.model.identity }
    var coordinateCount: Int { source.dimension }
    func validateDomain(at point: [Double], work: inout NumericalWork) throws(NonlinearCause) {
        guard !policy.isCancelled(),!policy.equilibrium.isCancelled() else { throw .numerical(.cancelled) }
        guard point.count==coordinateCount,point.allSatisfy({$0.isFinite}) else { throw .invalidEvaluation }
        let n=source.count,p=point[coordinateCount-1]*policy.parameterScale
        do { try forces.validate(source.model,point:point,parameter:p,work:&work) } catch { throw Self.cause(error) }
        for i in 0..<n {
            let q=point[i]*source.model.chart.scales[i]
            guard q>=source.branch.minimumPosition[i],q<=source.branch.maximumPosition[i] else { throw .equation(.outsideDomain) }
            if let c=source.constraints { guard q>=c.system.minimumPosition[i],q<=c.system.maximumPosition[i] else { throw .equation(.outsideDomain) } }
        }
    }
    func residual(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        try validateDomain(at:point,work:&work)
        let n=source.count,d=coordinateCount,p=point[d-1]*policy.parameterScale
        guard output.count==d else { throw .invalidEvaluation }
        do { try work.chargeOperations(try NumericalWork.product(8,try NumericalWork.product(n,d))) } catch { throw .numerical(error) }
        for i in 0..<n {
            do { output[i]=try forces.gradient(source.model,point:point,parameter:p,coordinate:i,work:&work)*source.model.chart.scales[i]/source.model.energyScale }
            catch { throw Self.cause(error) }
            if let c=source.constraints { for r in 0..<source.rowCount { output[i]+=c.system.rows[r].linear[i]*point[n+r] } }
        }
        if let c=source.constraints { for r in 0..<source.rowCount {
            var value=c.system.rows[r].constant
            for i in 0..<n { value+=c.system.rows[r].linear[i]*point[i] }
            output[n+r]=value
        } }
        var arc=direction[d-1]*(point[d-1]-predictor[d-1])
        for i in 0..<n { arc+=direction[i]*(point[i]-predictor[i]) }
        output[d-1]=arc
        guard output.allSatisfy({$0.isFinite}) else { throw .invalidEvaluation }
    }
    func originalResidual(at point: [Double], into output: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        // This callback reevaluates the original source laws rather than cached Newton rows.
        try residual(at:point,into:&output,work:&work)
    }
    func jacobian(at point: [Double], into rowMajorOutput: inout [Double], work: inout NumericalWork) throws(NonlinearCause) {
        try validateDomain(at:point,work:&work)
        let n=source.count,d=coordinateCount,p=point[d-1]*policy.parameterScale,S=source.model.chart.scales,E=source.model.energyScale
        guard rowMajorOutput.count==d*d else { throw .invalidEvaluation }
        do { try work.chargeOperations(try NumericalWork.product(8,rowMajorOutput.count)) } catch { throw .numerical(error) }
        for i in rowMajorOutput.indices { rowMajorOutput[i]=0 }
        for i in 0..<n {
            do {
                for j in 0..<n { rowMajorOutput[i*d+j]=try forces.tangent(source.model,point:point,parameter:p,row:i,column:j,work:&work)*S[i]*S[j]/E }
                rowMajorOutput[i*d+d-1]=try forces.parameterDerivative(source.model,point:point,parameter:p,coordinate:i,work:&work)*S[i]*policy.parameterScale/E
            } catch { throw Self.cause(error) }
        }
        if let c=source.constraints { for r in 0..<source.rowCount { for i in 0..<n {
            rowMajorOutput[i*d+n+r]=c.system.rows[r].linear[i];rowMajorOutput[(n+r)*d+i]=c.system.rows[r].linear[i]
        } } }
        for i in 0..<n { rowMajorOutput[(d-1)*d+i]=direction[i] }
        rowMajorOutput[d*d-1]=direction[d-1]
        guard rowMajorOutput.allSatisfy({$0.isFinite}) else { throw .invalidEvaluation }
    }
    private static func cause(_ error: StaticForceError) -> NonlinearCause {
        switch error { case .outsideDomain: .equation(.outsideDomain);case .numerical(let e): .numerical(e);default: .invalidEvaluation }
    }
}
