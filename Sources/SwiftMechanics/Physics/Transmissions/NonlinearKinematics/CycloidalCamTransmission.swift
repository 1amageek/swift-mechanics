#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

/// Selected ideal CycloidalCam geometry/profile; exact phase, domain and fidelity belong to DESIGN.md.
public struct CycloidalCamTransmission: Equatable, Sendable, NonlinearTransmissionEvaluating {
    public let lift: Double
    public let startAngle: Double
    public let riseAngle: Double
    public let outputOffset: Double
    public let inputDomain: TransmissionInputDomain

    public init(lift: Double, startAngle: Double = 0, riseAngle: Double, outputOffset: Double = 0) throws(NonlinearTransmissionError) {
        guard lift.isFinite, lift > 0, startAngle.isFinite, riseAngle.isFinite, riseAngle > 0, outputOffset.isFinite else { throw .invalidParameter(name: "cycloidalCam") }
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
        let u=(inputCoordinate-startAngle)/riseAngle
        let v=1-u, nearEnd=u > 0.5, distance=nearEnd ? v : u
        let fraction=NonlinearTransmissionMath.cycloidalFraction(distance)
        let output=nearEnd ? outputOffset+lift-lift*fraction : outputOffset+lift*fraction
        let sine=sin(Double.pi*distance)
        let derivative=(lift/riseAngle)*2*sine*sine
        let curvature=(lift/riseAngle)*(2*Double.pi/riseAngle)*sin(2*Double.pi*distance)*(nearEnd ? -1 : 1)
        return try NonlinearTransmissionSample(input: inputCoordinate, output: output, outputKind: .translation,
                                                derivative: derivative, curvature: curvature)
    }
}
