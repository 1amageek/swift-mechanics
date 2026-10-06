public enum RefinementError: Error, Sendable {
    case invalidInput, capacityExceeded, cancelled, nonFinite, identifierOverflow, identifierCollision
    case staleSource, staleRevision, staleLayout, frameMismatch, topologyPolicyMismatch
    case invalidAssignment, nonconformingMesh, invalidTopology, physicalResidual
    case unsupportedBoundaryMapping, unsupportedLoadMapping
    case core(CoreError), flexible(FlexibleError), numerical(NumericalError)
}
