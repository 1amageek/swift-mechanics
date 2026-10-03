import MechanicsNumerics
import MechanicsConstraints

public protocol TransmissionNetworkOperating: Sendable {
    func assemble(_ network: CompiledTransmissionNetwork, initialPosition: [Double], time: Double, assemblyPolicy: ConstraintSolvePolicy,
                  policy: TransmissionPolicy, work: inout NumericalWork, constraintWork: inout NumericalWork) throws(TransmissionError) -> TransmissionNetworkSolution
    func idealEfforts(_ network: CompiledTransmissionNetwork, position: [Double], velocity: [Double], normalizedEnergyMultipliers: [Double],
                      policy: TransmissionPolicy, work: inout NumericalWork) throws(TransmissionError) -> TransmissionIdealResponse
}
