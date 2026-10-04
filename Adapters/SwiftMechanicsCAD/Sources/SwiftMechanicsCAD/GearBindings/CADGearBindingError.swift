import SwiftMechanics

public enum CADGearBindingError: Error, Sendable {
    case invalidInput, staleSource, staleModel, unsupportedDomain, unsupportedFidelity
    case duplicateShaft, missingShaft, wrongOccurrence, wrongAnchor
    case incompatiblePlacement, incompatibleAxis, incompatibleModule, incompatiblePressure
    case incompatibleSpacing, incompatibleSweep, incompatibleMountingPhase
    case capacityExceeded, cancelled
    case cad(CADAdapterError)
    case compilation(CompilationFailure)
    case transmission(TransmissionError)
    case core(CoreError)
}

func gearCAD<Value>(_ body: () throws(CADAdapterError) -> Value) throws(CADGearBindingError) -> Value {
    do { return try body() } catch { throw .cad(error) }
}
func gearCore<Value>(_ body: () throws(CoreError) -> Value) throws(CADGearBindingError) -> Value {
    do { return try body() } catch { throw .core(error) }
}
