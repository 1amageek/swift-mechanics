public enum StationaryIslandFailureReason: Error, Sendable {
    case invalidInput, unsupportedDomain, sourceMismatch, capacityExceeded, cancelled
    case rankAmbiguity, residualRejected
    indirect case supplierLedgerFailure(StationaryIslandFailureReason?)
    indirect case compilation(CompilationFailure)
    indirect case kinematics(any Error)
    indirect case dynamics(DynamicsError)
    indirect case constraint(ConstraintError)
    indirect case mechanism(MechanismError)
    indirect case numerical(NumericalError)
    indirect case load(LoadError)
}
