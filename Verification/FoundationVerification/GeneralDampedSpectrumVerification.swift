import SwiftMechanics

extension FoundationVerification {
    @inline(never) static func verifyGeneralDampedSpectrum() throws {
        let context = try GeneralDampedSpectrumProbeContext()
        try require(context.pencil.count == 2)
        let rootTwo = Double(2).squareRoot()
        try require(context.pencil.mass == [1, 0, 0, 1])
        try require(context.pencil.stiffness == [2, 0, 0, 8])
        try require(context.pencil.damping == [1, rootTwo, rootTwo, 2])
        let spectralPolicy = try ComplexSpectrumPolicy(maximumDimension: 8, maximumQRIterations: 2000,
            deflationTolerance: 1e-13, eigenvectorPivotThreshold: 1e-12,
            originalResidualTolerance: 1e-9, isCancelled: { false })
        var work = NumericalWork(budget: context.budget)
        let service: any GeneralDampedModalAnalyzing = ReferenceGeneralDampedModalAnalyzer()
        let result = try service.modes(context.pencil, expectedBinding: context.binding,
            policy: context.policy, spectrumPolicy: spectralPolicy, work: &work)
        try require(result.binding == context.binding && result.poles.count == 4 && result.modes.count == 8)
        try require(result.work == work && work.operations > 0 && work.iterations > 0)
        try require(result.maximumOriginalQuadraticResidual < 1e-7 && result.maximumMassNormalizationError < 1e-7)
        try verifyIndependentDampedModes(context, result: result)
        try verifyGeneralDampedRefusals(context)
        print("General damped spectrum passed: four coupled analytic poles, complex modes and original quadratic equations.")
    }

    @inline(never) private static func verifyGeneralDampedRefusals(_ context: GeneralDampedSpectrumProbeContext) throws {
        let spectralPolicy = try ComplexSpectrumPolicy(maximumDimension: 8, maximumQRIterations: 0,
            deflationTolerance: 1e-13, eigenvectorPivotThreshold: 1e-12,
            originalResidualTolerance: 1e-9, isCancelled: { false })
        var work = NumericalWork(budget: context.budget), refused = false
        let service: any GeneralDampedModalAnalyzing = ReferenceGeneralDampedModalAnalyzer()
        do throws(GeneralDampedSpectrumFailure) {
            _ = try service.modes(context.pencil, expectedBinding: context.binding,
                policy: context.policy, spectrumPolicy: spectralPolicy, work: &work)
        } catch {
            if case .spectral(.nonConvergence) = error.cause { refused = true }
            try require(error.work == work && !error.failedSupplierWorkUnavailable)
        }
        try require(refused && work.operations > 0 && work.iterations == 0)
        let cancelled = try StructuralPolicy(maximumCoordinates: context.policy.maximumCoordinates,
            maximumMetadataBytes: context.policy.maximumMetadataBytes,
            energyScale: context.policy.energyScale, timeScale: context.policy.timeScale,
            spectralTolerance: context.policy.spectralTolerance,
            positiveMassThreshold: context.policy.positiveMassThreshold,
            originalResidualTolerance: context.policy.originalResidualTolerance,
            zeroEigenvalueThreshold: context.policy.zeroEigenvalueThreshold, isCancelled: { true })
        var cancelledWork = NumericalWork(budget: context.budget), cancellationRefused = false
        do throws(GeneralDampedSpectrumFailure) {
            _ = try service.modes(context.pencil, expectedBinding: context.binding,
                policy: cancelled, spectrumPolicy: spectralPolicy, work: &cancelledWork)
        } catch {
            if case .structural(.cancelled) = error.cause { cancellationRefused = true }
            try require(error.work == cancelledWork && !error.failedSupplierWorkUnavailable)
        }
        try require(cancellationRefused && cancelledWork.operations == 0)
    }

    @inline(never) private static func verifyIndependentDampedModes(_ context: GeneralDampedSpectrumProbeContext,
                                                                   result: GeneralDampedModalResult) throws {
        let expected = context.expectedPoles
        var matched = 0
        for index in 0..<4 {
            let pole = result.poles[index]
            var match: Int? = nil
            for candidate in 0..<4 where matched & (1 << candidate) == 0 {
                if abs(pole.real - expected[candidate].real) < 1e-7 &&
                   abs(pole.imaginary - expected[candidate].imaginary) < 1e-7 { match = candidate; break }
            }
            guard let match else { throw FoundationVerificationError.analyticCheckFailed }
            matched |= 1 << match
            let first = result.modes[2 * index], second = result.modes[2 * index + 1]
            let ratio = try context.modeRatio(pole)
            let expectedSecondReal = ratio.real * first.real - ratio.imaginary * first.imaginary
            let expectedSecondImaginary = ratio.real * first.imaginary + ratio.imaginary * first.real
            try require(abs(second.real - expectedSecondReal) < 1e-7 &&
                        abs(second.imaginary - expectedSecondImaginary) < 1e-7)
            let norm = first.real * first.real + first.imaginary * first.imaginary +
                       second.real * second.real + second.imaginary * second.imaginary
            try require(abs(norm - 1) < 1e-7)
            try verifyIndependentQuadraticRows(context.pencil, pole: pole,
                                               first: first, second: second)
        }
        try require(matched == 15)
    }

    @inline(never) private static func verifyIndependentQuadraticRows(_ pencil: StructuralPencil,
                                                                     pole: SpectrumComplex,
                                                                     first: SpectrumComplex,
                                                                     second: SpectrumComplex) throws {
        let squaredReal = pole.real * pole.real - pole.imaginary * pole.imaginary
        let squaredImaginary = 2 * pole.real * pole.imaginary
        for row in 0..<2 {
            var residualReal = 0.0, residualImaginary = 0.0
            for column in 0..<2 {
                let entry = row * 2 + column, value = column == 0 ? first : second
                let real = pencil.stiffness[entry] + pole.real * pencil.damping[entry] + squaredReal * pencil.mass[entry]
                let imaginary = pole.imaginary * pencil.damping[entry] + squaredImaginary * pencil.mass[entry]
                residualReal += real * value.real - imaginary * value.imaginary
                residualImaginary += real * value.imaginary + imaginary * value.real
            }
            try require(abs(residualReal) < 1e-7 && abs(residualImaginary) < 1e-7)
        }
    }
}
