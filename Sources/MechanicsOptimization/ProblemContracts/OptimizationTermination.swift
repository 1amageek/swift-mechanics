public enum OptimizationTermination: Equatable, Sendable {
    case invalidProblem, unsupportedDomain, nonconverged, rankIndeterminate, resourceLimit, cancelled, supplierFailure, arithmeticFailure
}
