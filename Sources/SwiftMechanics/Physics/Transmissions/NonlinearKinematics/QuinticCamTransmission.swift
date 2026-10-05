#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

/// Selected ideal QuinticCam geometry/profile; exact phase, domain and fidelity belong to DESIGN.md.
public struct QuinticCamTransmission: Equatable, Sendable, NonlinearTransmissionEvaluating {
    public let lift: Double
    public let startAngle: Double
    public let riseAngle: Double
    public let outputOffset: Double
    public let inputDomain: TransmissionInputDomain

    public init(lift: Double, startAngle: Double = 0, riseAngle: Double, outputOffset: Double = 0) throws(NonlinearTransmissionError) {
        guard lift.isFinite, lift > 0, startAngle.isFinite, riseAngle.isFinite, riseAngle > 0, outputOffset.isFinite else { throw .invalidParameter(name: "quinticCam") }
        inputDomain=try TransmissionInputDomain(minimum: startAngle, maximum: startAngle+riseAngle)
        self.lift=lift; self.startAngle=startAngle; self.riseAngle=riseAngle; self.outputOffset=outputOffset
    }

    public func evaluate(inputCoordinate: Double) throws(NonlinearTransmissionError) -> NonlinearTransmissionSample {
        try inputDomain.validate(inputCoordinate)
        if inputCoordinate == inputDomain.minimum || inputCoordinate == inputDomain.maximum {
            return try NonlinearTransmissionSample(input: inputCoordinate,
                output: inputCoordinate == inputDomain.minimum ? outputOffset : outputOffset+lift,
                outputKind: .translation, derivative: 0, curvature: 0)
        }
        let u=(inputCoordinate-startAngle)/riseAngle, v=1-u, distance=u > 0.5 ? v : u
        let fraction=distance*distance*distance*(10+distance*(-15+6*distance))
        let output=u > 0.5 ? outputOffset+lift-lift*fraction : outputOffset+lift*fraction
        let derivative=(lift/riseAngle)*30*u*u*v*v
        let curvature=(lift/riseAngle)*(60/riseAngle)*u*v*(1-2*u)
        return try NonlinearTransmissionSample(input: inputCoordinate, output: output, outputKind: .translation,
                                                derivative: derivative, curvature: curvature)
    }
}
