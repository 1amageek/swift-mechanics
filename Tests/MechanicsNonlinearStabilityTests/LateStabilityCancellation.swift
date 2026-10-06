import SwiftMechanics
import Synchronization

@available(macOS 15.0, *)
struct LateStabilityCancellation: ComplexSpectralSolving {
    let cancellation: StabilityCancellation
    func solve(_ matrix: ComplexSpectralMatrix,policy: ComplexSpectrumPolicy,work: inout NumericalWork)
        throws(ComplexSpectrumError) -> ComplexSpectrumResult {
        let result=try ReferenceComplexSpectralSolver().solve(matrix,policy:policy,work:&work)
        cancellation.cancel()
        return result
    }
}
