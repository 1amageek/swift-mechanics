import MechanicsCore
import MechanicsNumerics
public enum PatchError: Error, Sendable {
    case invalidInput, invalidLayout, staleRepresentation, incompatibleMaterial, frameMismatch, missingPressureField
    case unsupportedPair, degenerateCut, invertedCell(UInt64), capacityExceeded, cancelled, nonFiniteResult, residualRejected
    case core(CoreError), numerical(NumericalError)
}
