public struct StructuralImplicitPolicy: Sendable {
    public let parameters: GeneralizedAlphaParameters
    public let residualScales: [StructuralResidualScale]
    public let nonlinear: NonlinearPolicy<Double>
    public init(parameters: GeneralizedAlphaParameters, residualScales: [StructuralResidualScale],
                nonlinear: NonlinearPolicy<Double>) throws(ImplicitMethodCause) {
        guard !residualScales.isEmpty else { throw .invalidInput }
        self.parameters = parameters; self.residualScales = residualScales; self.nonlinear = nonlinear
    }
}
