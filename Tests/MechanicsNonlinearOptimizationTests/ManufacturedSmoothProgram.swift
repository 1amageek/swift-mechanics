import SwiftMechanics

struct ManufacturedSmoothProgram<Scalar: NumericalScalar>: SmoothNonlinearProgramProviding, Sendable {
    enum Mode: Equatable, Sendable { case curved,activeCurve,bound,saddle,weakActive,rank,nearRank,singular,dishonest,badHessian,partial,resized,ledgerReset,customFailure,domainFailure }
    let layout: NonlinearProgramLayout,mode: Mode
    func validateDomain(at x: [Scalar],work: inout NumericalWork) throws(NonlinearCause) {
        if mode == .ledgerReset { work=NumericalWork(budget:work.budget); return }
        do { try work.chargeOperations(2) } catch { throw .numerical(error) }
        if mode == .customFailure { throw .equation(.evaluationFailed(code:17)) }
        if mode == .domainFailure { throw .equation(.outsideDomain) }
    }
    func values(at x: [Scalar],into v: inout NonlinearProgramValues<Scalar>,work: inout NumericalWork) throws(NonlinearCause) {
        try fill(x,into:&v,original:false,work:&work)
    }
    func originalValues(at x: [Scalar],into v: inout NonlinearProgramValues<Scalar>,work: inout NumericalWork) throws(NonlinearCause) {
        try fill(x,into:&v,original:true,work:&work)
    }
    private func fill(_ x: [Scalar],into v: inout NonlinearProgramValues<Scalar>,original: Bool,work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(40) } catch { throw .numerical(error) }
        for i in v.equalities.indices { v.equalities[i]=0 }
        for i in v.inequalities.indices { v.inequalities[i]=0 }
        for i in v.equalityJacobian.indices { v.equalityJacobian[i]=0 }
        for i in v.inequalityJacobian.indices { v.inequalityJacobian[i]=0 }
        switch mode {
        case .curved,.badHessian:
            let a=x[0]-3,b=x[1]
            v.objective=(a*a+b*b)/2; v.gradient[0]=a;v.gradient[1]=b
            v.equalities[0]=x[0]*x[0]-x[1];v.equalityJacobian[0]=2*x[0];v.equalityJacobian[1] = -1
        case .activeCurve:
            let a=x[0]-2,b=x[1]
            v.objective=(a*a+b*b)/2;v.gradient[0]=a;v.gradient[1]=b
            v.inequalities[0]=x[0]*x[0]-1;v.inequalityJacobian[0]=2*x[0]
        case .bound:
            let a=x[0]-3;v.objective=a*a/2;v.gradient[0]=a
        case .saddle:
            v.objective=(x[0]*x[0]-x[1]*x[1])/2;v.gradient[0]=x[0];v.gradient[1] = -x[1]
        case .weakActive:
            v.objective = -x[0]*x[0];v.gradient[0] = -2*x[0];v.inequalities[0]=x[0];v.inequalityJacobian[0]=1
        case .rank,.nearRank:
            v.objective=(x[0]*x[0]+x[1]*x[1])/2;v.gradient[0]=x[0];v.gradient[1]=x[1]
            v.equalities[0]=x[0];v.equalityJacobian[0]=1
            if mode == .rank { v.equalities[1]=x[0];v.equalityJacobian[2]=1 }
            else { let a=Scalar(1e-16);v.equalities[1]=a*x[1];v.equalityJacobian[3]=a }
        case .singular:
            v.objective=x[0];v.gradient[0]=1
        default:
            let a=x[0]-1;v.objective=a*a/2;v.gradient[0]=a
            if mode == .dishonest && !original { v.gradient[0]=0 }
            if mode == .partial { v.objective = .nan }
            if mode == .resized { v.gradient.removeLast() }
        }
    }
    func lagrangianHessian(at x: [Scalar],equalityMultipliers e: [Scalar],inequalityMultipliers g: [Scalar],into h: inout [Scalar],work: inout NumericalWork) throws(NonlinearCause) {
        do { try work.chargeOperations(10) } catch { throw .numerical(error) }
        for i in h.indices { h[i]=1 }
        switch mode {
        case .curved: h[0]=1+2*e[0]
        case .activeCurve: h[0]=1+2*g[0]
        case .saddle: h[1] = -1
        case .weakActive: h[0] = -2
        case .singular: h[0]=0
        default: break
        }
    }
}
