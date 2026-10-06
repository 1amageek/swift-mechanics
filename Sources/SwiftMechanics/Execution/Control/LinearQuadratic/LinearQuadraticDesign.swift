public struct LinearQuadraticDesign: Sendable {
    public let system: DiscreteControlSystem
    public let stateCost: [Double]
    public let inputCost: [Double]
    /// Row-major normalized-coordinate P and gain K, with u=-K*x.
    public let riccatiMatrix: [Double]
    public let feedbackGain: [Double]
    public let diagnostics: LinearQuadraticDiagnostics
}
