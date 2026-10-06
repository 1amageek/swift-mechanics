public enum SpatialBeamMassForm: Equatable, Sendable {
    /// Exact polynomial integration of translation and all declared section rotary inertias.
    case consistent
    /// Endpoint quadrature; transverse line-distribution inertia is an explicit approximation.
    case endpointLumped
}
