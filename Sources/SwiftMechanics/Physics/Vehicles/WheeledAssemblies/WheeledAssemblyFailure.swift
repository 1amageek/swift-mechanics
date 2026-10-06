public enum WheeledAssemblyFailure: Error, Sendable {
    public enum Refusal: Equatable, Sendable {
        case invalidInput, unsupportedTopology, unsupportedModelFeatures, unsupportedRoadPort
        case staleState, outsideCalibration, brakeAtZeroSpeed, brakeSpinCrossing
        case sequenceOverflow, workExhausted, cancelled, terminalSupplierFailure
        case instantaneousPower, energyResidual, cumulativeEnergyDefect, linearMomentum, angularMomentum
    }
    case refusal(Refusal)
    case residual(kind: Refusal, value: Double, scale: Double)
    case core(CoreError)
    case compilation(CompilationFailure)
    case joints(JointError)
    case loads(LoadError)
    case actuation(ActuationError)
    case dynamics(DynamicsError)
    case numerical(NumericalError)
}
