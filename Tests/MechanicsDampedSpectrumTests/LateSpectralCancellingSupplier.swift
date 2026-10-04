import SwiftMechanics

/// A valid numerical supplier deliberately bypasses the cancellation callback, then cancels its caller.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct LateSpectralCancellingSupplier: ComplexSpectralSolving, Sendable {
    let flag:SpectrumCancellationFlag
    func solve(_ matrix:ComplexSpectralMatrix,policy:ComplexSpectrumPolicy,work:inout NumericalWork) throws(ComplexSpectrumError) -> ComplexSpectrumResult {
        let bypass=try ComplexSpectrumPolicy(maximumDimension:policy.maximumDimension,maximumQRIterations:policy.maximumQRIterations,
            deflationTolerance:policy.deflationTolerance,eigenvectorPivotThreshold:policy.eigenvectorPivotThreshold,
            originalResidualTolerance:policy.originalResidualTolerance,isCancelled:{false})
        let result=try ReferenceComplexSpectralSolver().solve(matrix,policy:bypass,work:&work)
        flag.cancel()
        return result
    }
}
