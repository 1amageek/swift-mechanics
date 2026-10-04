public struct ComplementaritySolution: Sendable {
    public let values: [Double]
    public let dualValues: [Double]
    public let objective: Double
    public let cache: ComplementarityCache
    public let diagnostics: ComplementarityDiagnostics
}
