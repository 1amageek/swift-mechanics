#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

/// Selected ideal HarmonicCam geometry/profile; exact phase, domain and fidelity belong to DESIGN.md.
public struct HarmonicCamTransmission: Equatable, Sendable, NonlinearTransmissionEvaluating {
    public let lift: Double
    public let inputPhase: Double
    public let outputOffset: Double
    public let inputDomain: TransmissionInputDomain

    public init(lift: Double, inputPhase: Double = 0, outputOffset: Double = 0,
                inputDomain: TransmissionInputDomain) throws(NonlinearTransmissionError) {
        guard lift.isFinite, lift > 0, inputPhase.isFinite, outputOffset.isFinite else { throw .invalidParameter(name: "harmonicCam") }
        self.lift=lift; self.inputPhase=inputPhase; self.outputOffset=outputOffset; self.inputDomain=inputDomain
    }

    public func evaluate(inputCoordinate: Double) throws(NonlinearTransmissionError) -> NonlinearTransmissionSample {
        try inputDomain.validate(inputCoordinate)
        let theta=try NonlinearTransmissionMath.finite(inputCoordinate-inputPhase), halfSine=sin(theta/2)
        return try NonlinearTransmissionSample(input: inputCoordinate, output: outputOffset+lift*halfSine*halfSine,
            outputKind: .translation, derivative: (lift/2)*sin(theta), curvature: (lift/2)*cos(theta))
    }
}
