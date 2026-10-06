#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

/// Selected ideal Cardan geometry/profile; exact phase, domain and fidelity belong to DESIGN.md.
public struct CardanTransmission: Equatable, Sendable, NonlinearTransmissionEvaluating {
    public let shaftAngle: Double
    public let inputPhase: Double
    public let outputPhase: Double
    public let inputDomain: TransmissionInputDomain

    public init(shaftAngle: Double, inputPhase: Double = 0, outputPhase: Double = 0,
                inputDomain: TransmissionInputDomain) throws(NonlinearTransmissionError) {
        guard shaftAngle.isFinite, abs(shaftAngle) < Double.pi/2, inputPhase.isFinite, outputPhase.isFinite else {
            throw .invalidParameter(name: "cardan")
        }
        self.shaftAngle=shaftAngle; self.inputPhase=inputPhase; self.outputPhase=outputPhase; self.inputDomain=inputDomain
    }

    public func evaluate(inputCoordinate: Double) throws(NonlinearTransmissionError) -> NonlinearTransmissionSample {
        try inputDomain.validate(inputCoordinate)
        let theta=try NonlinearTransmissionMath.finite(inputCoordinate-inputPhase), c=cos(shaftAngle)
        let sine=sin(theta), cosine=cos(theta), denominator=cosine*cosine+c*c*sine*sine
        let correction=atan2((c-1)*sine*cosine,cosine*cosine+c*sine*sine)
        let derivative=c/denominator
        let curvature=2*c*(1-c*c)*sine*cosine/denominator/denominator
        return try NonlinearTransmissionSample(input: inputCoordinate, output: outputPhase+theta+correction,
                                                outputKind: .rotation, derivative: derivative, curvature: curvature)
    }
}
