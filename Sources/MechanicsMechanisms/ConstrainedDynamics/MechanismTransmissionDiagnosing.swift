import MechanicsNumerics
import MechanicsTransmissions

public protocol MechanismTransmissionDiagnosing: Sendable {
    func diagnose(_ network: CompiledTransmissionNetwork, position:[Double], velocity:[Double], motion:ConstrainedMotion,
                  policy:TransmissionPolicy, work:inout NumericalWork) throws(MechanismError) -> TransmissionIdealResponse
}
