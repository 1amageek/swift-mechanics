import SwiftMechanics

public enum CADGearReinitializationError: Error, Sendable {
    case invalidInput, unsupportedDomain, unsupportedCatalog, unsupportedMigration
    case staleSource, staleModel, incompatibleTime, incompatibleRecipe, capacityExceeded, cancelled
    case cad(CADAdapterError), compilation(CompilationFailure), gear(CADGearBindingError)
    case mechanism(MechanismError), runtime(RuntimeFailure)
    case core(CoreError), constraint(ConstraintError), numerical(NumericalError), transmission(TransmissionError)
}
