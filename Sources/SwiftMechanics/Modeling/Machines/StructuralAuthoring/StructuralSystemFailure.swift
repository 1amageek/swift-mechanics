public enum StructuralSystemFailure: Error, Sendable {
    case invalidInput
    case capacityExceeded
    case invalidBinding(EntityID)
    case missingJoint(EntityID)
    case duplicateNumericIdentity(UInt64)
    case unsupportedJoint(EntityID)
    case movingGearSupport(EntityID)
    case missingInertia(EntityID)
    case missingTransmission
    case missingPassiveCatalog
    case requiresLoadedEquation
    case definition(MachineDefinitionFailure)
    case compilation(CompilationFailure)
    case transmission(TransmissionError)
    case loads(LoadError)
    case stationary(StationaryLoadError)
    case actuation(ActuationError)
    case constraint(ConstraintError)
    case mechanism(MechanismError)
    case runtime(RuntimeFailure)
    case numerical(NumericalError)

    public var failedSupplierWorkUnavailable: Bool {
        switch self {
        case .transmission(let failure): failure.failedSupplierWorkUnavailable
        case .stationary(let failure): failure.failedSupplierWorkUnavailable
        case .mechanism(let failure): failure.failedSupplierWorkUnavailable
        case .runtime(let failure): failure.failedSupplierWorkUnavailable
        default: false
        }
    }
}
