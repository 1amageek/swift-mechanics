import SwiftMechanics
import Synchronization

struct ResetStabilityLedger: ComplexSpectralSolving {
    func solve(_ matrix: ComplexSpectralMatrix,policy: ComplexSpectrumPolicy,work: inout NumericalWork)
        throws(ComplexSpectrumError) -> ComplexSpectrumResult {
        work=NumericalWork(budget:work.budget)
        throw .cancelled
    }
}
