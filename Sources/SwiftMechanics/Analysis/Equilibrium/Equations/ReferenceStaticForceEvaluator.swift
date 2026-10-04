public struct ReferenceStaticForceEvaluator<Scalar: NumericalScalar>: StaticForceEvaluating, Sendable {
    public init() {}
    public func validate(_ model: StaticForceModel, point: [Scalar], parameter: Scalar, work: inout NumericalWork) throws(StaticForceError) {
        let n=model.chart.count
        guard point.count>=n, parameter.isFinite, parameter>=Scalar(model.minimumParameter), parameter<=Scalar(model.maximumParameter) else { throw .outsideDomain }
        try charge(n, work: &work)
        for i in 0..<n {
            let q=point[i]*Scalar(model.chart.scales[i])
            guard q.isFinite, q>=Scalar(model.minimumPosition[i]),q<=Scalar(model.maximumPosition[i]) else { throw .outsideDomain }
        }
    }
    public func gradient(_ model: StaticForceModel, point: [Scalar], parameter: Scalar, coordinate i: Int, work: inout NumericalWork) throws(StaticForceError) -> Scalar {
        try validate(model, point: point, parameter: parameter, work: &work)
        guard i>=0,i<model.chart.count else { throw .invalidInput }
        try charge(10, work: &work)
        let q=point[i]*Scalar(model.chart.scales[i]); let value: Scalar
        switch model.law {
        case .springs(let a,let b,let c,let l): value=Scalar(a[i])*q + Scalar(b[i])*q*q*q - Scalar(c[i])-parameter*Scalar(l[i])
        case .pendulum(let g,let t): value=Scalar(g)*Scalar(ScalarMath.sine(Double(q)))-parameter*Scalar(t)
        }
        return try finite(value)
    }
    public func tangent(_ model: StaticForceModel, point: [Scalar], parameter: Scalar, row: Int, column: Int, work: inout NumericalWork) throws(StaticForceError) -> Scalar {
        try validate(model, point: point, parameter: parameter, work: &work)
        guard row>=0,row<model.chart.count,column>=0,column<model.chart.count else { throw .invalidInput }
        try charge(8, work: &work)
        if row != column { return 0 }
        let q=point[row]*Scalar(model.chart.scales[row]); let value: Scalar
        switch model.law {
        case .springs(let a,let b,_,_): value=Scalar(a[row])+Scalar(3)*Scalar(b[row])*q*q
        case .pendulum(let g,_): value=Scalar(g)*Scalar(ScalarMath.cosine(Double(q)))
        }
        return try finite(value)
    }
    public func parameterDerivative(_ model: StaticForceModel, point: [Scalar], parameter: Scalar, coordinate i: Int, work: inout NumericalWork) throws(StaticForceError) -> Scalar {
        try validate(model, point: point, parameter: parameter, work: &work)
        guard i>=0,i<model.chart.count else { throw .invalidInput }
        try charge(1, work: &work)
        switch model.law { case .springs(_,_,_,let l): return try finite(-Scalar(l[i])); case .pendulum(_,let t): return try finite(-Scalar(t)) }
    }
    public func energy(_ model: StaticForceModel, point: [Scalar], parameter: Scalar, work: inout NumericalWork) throws(StaticForceError) -> Scalar {
        try validate(model, point: point, parameter: parameter, work: &work)
        try charge(try product(16,model.chart.count), work: &work)
        var value: Scalar=0
        switch model.law {
        case .springs(let a,let b,let c,let l):
            for i in 0..<model.chart.count { let q=point[i]*Scalar(model.chart.scales[i]); let q2=q*q
                value += Scalar(a[i])*q2/Scalar(2)+Scalar(b[i])*q2*q2/Scalar(4)-Scalar(c[i])*q-parameter*Scalar(l[i])*q }
        case .pendulum(let g,let t):
            let q=point[0]*Scalar(model.chart.scales[0]); value=Scalar(g)*(Scalar(1)-Scalar(ScalarMath.cosine(Double(q))))-parameter*Scalar(t)*q
        }
        return try finite(value)
    }
    private func finite(_ value: Scalar) throws(StaticForceError) -> Scalar { guard value.isFinite else { throw .nonFiniteResult }; return value }
    private func charge(_ count: Int, work: inout NumericalWork) throws(StaticForceError) { do { try work.chargeOperations(count) } catch { throw .numerical(error) } }
    private func product(_ a: Int,_ b: Int) throws(StaticForceError)->Int { do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) } }
}
