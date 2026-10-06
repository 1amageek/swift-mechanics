public enum DiscreteControlProvenance: Sendable {
    /// The caller owns analytic model validity; this does not certify a mechanical linearization.
    case analytic(identity: String)
    /// The original IM17 result is retained with the explicit approximation and input calibration.
    indirect case equilibriumBilinear(source: EquilibriumLinearization, parameterChangePerInputUnit: Double)
}
