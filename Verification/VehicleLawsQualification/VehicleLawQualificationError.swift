import SwiftMechanics

public enum VehicleLawQualificationError: Error {
    case assertion(String)
    case unexpectedTireFailure(expected: String, actual: TireLawError)
    case unexpectedTerrainFailure(expected: String, actual: TerrainLawError)
    case unexpectedSuccess(String)
}
