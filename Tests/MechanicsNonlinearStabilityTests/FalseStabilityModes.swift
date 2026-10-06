import SwiftMechanics
import Synchronization

struct FalseStabilityModes: ComplexSpectralSolving {
    func solve(_ matrix: ComplexSpectralMatrix,policy: ComplexSpectrumPolicy,work: inout NumericalWork)
        throws(ComplexSpectrumError) -> ComplexSpectrumResult {
        let actual=try ReferenceComplexSpectralSolver().solve(matrix,policy:policy,work:&work)
        let falseValues=[SpectrumComplex](repeating:SpectrumComplex(real:5,imaginary:0),count:actual.dimension)
        return ComplexSpectrumResult(dimension:actual.dimension,eigenvalues:falseValues,eigenvectors:actual.eigenvectors,maximumOriginalResidual:0,work:work)
    }
}
