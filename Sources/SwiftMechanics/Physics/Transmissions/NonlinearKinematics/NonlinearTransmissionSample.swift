public struct NonlinearTransmissionSample: Equatable, Sendable {
    public let inputCoordinate: Double
    public let outputCoordinate: Double
    public let inputKind: ScalarCoordinateKind
    public let outputKind: ScalarCoordinateKind
    public let derivative: Double
    public let curvature: Double

    internal init(input: Double, output: Double, outputKind: ScalarCoordinateKind,
                  derivative: Double, curvature: Double) throws(NonlinearTransmissionError) {
        guard input.isFinite, output.isFinite, derivative.isFinite, curvature.isFinite else {
            throw .nonFiniteResult(operation: "nonlinearTransmissionSample")
        }
        inputCoordinate=input; outputCoordinate=output; inputKind = .rotation; self.outputKind=outputKind
        self.derivative=derivative; self.curvature=curvature
    }

    public func motion(inputRate: Double, inputAcceleration: Double) throws(NonlinearTransmissionError) -> TransmissionKinematicMotion {
        guard inputRate.isFinite, inputAcceleration.isFinite else { throw .invalidInput(name: "inputMotion") }
        let rate=try NonlinearTransmissionMath.finite(derivative*inputRate)
        let acceleration=try NonlinearTransmissionMath.finite(derivative*inputAcceleration+curvature*inputRate*inputRate)
        return TransmissionKinematicMotion(inputRate: inputRate, inputAcceleration: inputAcceleration,
                                           outputRate: rate, outputAcceleration: acceleration)
    }

    public func pullBack(outputEffort: Double, inputRate: Double) throws(NonlinearTransmissionError) -> TransmissionPowerResponse {
        guard outputEffort.isFinite, inputRate.isFinite else { throw .invalidInput(name: "inputPower") }
        let effort=try NonlinearTransmissionMath.finite(derivative*outputEffort)
        let outputRate=try NonlinearTransmissionMath.finite(derivative*inputRate)
        let pin=try NonlinearTransmissionMath.finite(effort*inputRate)
        let pout=try NonlinearTransmissionMath.finite(outputEffort*outputRate)
        return TransmissionPowerResponse(inputEffort: effort, outputEffort: outputEffort,
            inputPower: pin, outputPower: pout, balanceResidual: try NonlinearTransmissionMath.finite(pin-pout))
    }

    public func inputRate(forOutputRate rate: Double, minimumAbsoluteDerivative: Double) throws(NonlinearTransmissionError) -> Double {
        try invert(rate, minimumAbsoluteDerivative: minimumAbsoluteDerivative)
    }

    public func outputEffort(forInputEffort effort: Double, minimumAbsoluteDerivative: Double) throws(NonlinearTransmissionError) -> Double {
        try invert(effort, minimumAbsoluteDerivative: minimumAbsoluteDerivative)
    }

    /// An instantaneous derivative only; the caller retains model/frame and nonlinear sample association.
    public func instantaneousAffine(model: ModelStamp, frame: EntityID, work: inout ActuationWork) throws(ActuationError) -> AffineTransmission {
        try work.reserve(scalars: 1)
        return try AffineTransmission(model: model, frame: frame, outputCoordinate: outputKind,
            inputCoordinates: [inputKind], gradient: [derivative], prescribedRate: 0, work: &work)
    }

    private func invert(_ value: Double, minimumAbsoluteDerivative threshold: Double) throws(NonlinearTransmissionError) -> Double {
        guard value.isFinite, threshold.isFinite, threshold >= 0 else { throw .invalidInput(name: "localInverse") }
        guard abs(derivative) > threshold else { throw .singularInverse(derivative: derivative, minimumAbsoluteDerivative: threshold) }
        return try NonlinearTransmissionMath.finite(value/derivative)
    }
}
