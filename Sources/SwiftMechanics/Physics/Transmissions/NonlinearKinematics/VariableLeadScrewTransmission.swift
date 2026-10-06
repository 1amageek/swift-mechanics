#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

/// Selected ideal VariableLeadScrew geometry/profile; exact phase, domain and fidelity belong to DESIGN.md.
public struct VariableLeadScrewTransmission: Equatable, Sendable, NonlinearTransmissionEvaluating {
    public let leadAtPhase: Double
    public let leadSlope: Double
    public let inputPhase: Double
    public let outputOffset: Double
    public let inputDomain: TransmissionInputDomain

    public init(leadAtPhase: Double, leadSlope: Double, inputPhase: Double = 0, outputOffset: Double = 0,
                inputDomain: TransmissionInputDomain) throws(NonlinearTransmissionError) {
        guard leadAtPhase.isFinite, leadSlope.isFinite, inputPhase.isFinite, outputOffset.isFinite else { throw .invalidParameter(name: "variableLeadScrew") }
        let first=leadAtPhase+leadSlope*(inputDomain.minimum-inputPhase)
        let last=leadAtPhase+leadSlope*(inputDomain.maximum-inputPhase)
        guard first.isFinite, last.isFinite, (first > 0 && last > 0) || (first < 0 && last < 0) else {
            throw .invalidParameter(name: "signedLeadDomain")
        }
        self.leadAtPhase=leadAtPhase; self.leadSlope=leadSlope; self.inputPhase=inputPhase
        self.outputOffset=outputOffset; self.inputDomain=inputDomain
    }

    public func evaluate(inputCoordinate: Double) throws(NonlinearTransmissionError) -> NonlinearTransmissionSample {
        try inputDomain.validate(inputCoordinate)
        let theta=try NonlinearTransmissionMath.finite(inputCoordinate-inputPhase)
        let output=outputOffset+theta*(leadAtPhase+leadSlope*theta/2)
        return try NonlinearTransmissionSample(input: inputCoordinate, output: output, outputKind: .translation,
            derivative: leadAtPhase+leadSlope*theta, curvature: leadSlope)
    }
}
