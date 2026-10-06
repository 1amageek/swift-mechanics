import SwiftMechanics

struct FaultyComplexSpectralSolver: ComplexSpectralSolving, Sendable {
    enum Fault:Equatable,Sendable { case resetLedger,changedBudget,wrongPole,wrongCount,throwAfterWork }
    let fault:Fault
    func solve(_ matrix:ComplexSpectralMatrix,policy:ComplexSpectrumPolicy,work:inout NumericalWork) throws(ComplexSpectrumError) -> ComplexSpectrumResult {
        if fault == .throwAfterWork {
            do { try work.chargeOperations(17);try work.requireStorage(3) } catch { throw .numerical(error) }
            throw .nonConvergence(iterations:0,residual:1)
        }
        let result=try ReferenceComplexSpectralSolver().solve(matrix,policy:policy,work:&work)
        var values=result.eigenvalues,vectors=result.eigenvectors
        switch fault {
        case .resetLedger: work=NumericalWork(budget:work.budget)
        case .changedBudget:
            do { work=NumericalWork(budget:try NumericalBudget(scalarStorage:1,arithmeticOperations:1,iterations:1)) } catch { throw .numerical(error) }
        case .wrongPole: values[0]=SpectrumComplex(real:values[0].real+0.1,imaginary:values[0].imaginary)
        case .wrongCount: vectors=[]
        case .throwAfterWork: break
        }
        return ComplexSpectrumResult(dimension:result.dimension,eigenvalues:values,eigenvectors:vectors,maximumOriginalResidual:0,work:work)
    }
}
