#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

/// Selected ideal SliderCrank geometry/profile; exact phase, domain and fidelity belong to DESIGN.md.
public struct SliderCrankTransmission: Equatable, Sendable, NonlinearTransmissionEvaluating {
    public let crankRadius: Double
    public let rodLength: Double
    public let sliderOffset: Double
    public let inputPhase: Double
    public let outputOffset: Double
    public let assembly: SliderCrankAssembly
    public let inputDomain: TransmissionInputDomain

    public init(crankRadius: Double, rodLength: Double, sliderOffset: Double = 0, inputPhase: Double = 0,
                outputOffset: Double = 0, assembly: SliderCrankAssembly, inputDomain: TransmissionInputDomain) throws(NonlinearTransmissionError) {
        guard crankRadius.isFinite, crankRadius > 0, rodLength.isFinite, rodLength > 0,
              sliderOffset.isFinite, inputPhase.isFinite, outputOffset.isFinite else { throw .invalidParameter(name: "sliderCrank") }
        self.crankRadius=crankRadius; self.rodLength=rodLength; self.sliderOffset=sliderOffset
        self.inputPhase=inputPhase; self.outputOffset=outputOffset; self.assembly=assembly; self.inputDomain=inputDomain
    }

    public func evaluate(inputCoordinate: Double) throws(NonlinearTransmissionError) -> NonlinearTransmissionSample {
        try inputDomain.validate(inputCoordinate)
        let theta=try NonlinearTransmissionMath.finite(inputCoordinate-inputPhase)
        let sine=sin(theta), cosine=cos(theta)
        let y=try NonlinearTransmissionMath.finite(sliderOffset-crankRadius*sine)
        guard abs(y) <= rodLength else { throw .impossibleClosure }
        guard abs(y) < rodLength else { throw .singularClosure }
        let t=y/rodLength, root=((1-abs(t))*(1+abs(t))).squareRoot()
        guard root > 0 else { throw .singularClosure }
        let dy = -crankRadius*cosine, ddy=crankRadius*sine
        let rodDerivative = -t*dy/root
        let rodCurvature = -(dy/rodLength)*(dy/root)/root/root-t*ddy/root
        let output=outputOffset+crankRadius*cosine+assembly.sign*rodLength*root
        let derivative = -crankRadius*sine+assembly.sign*rodDerivative
        let curvature = -crankRadius*cosine+assembly.sign*rodCurvature
        return try NonlinearTransmissionSample(input: inputCoordinate, output: output, outputKind: .translation,
                                                derivative: derivative, curvature: curvature)
    }
}
