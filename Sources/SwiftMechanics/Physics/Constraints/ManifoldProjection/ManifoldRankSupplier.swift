internal enum ManifoldRankSupplier: Sendable {
    case full(any ConstraintRankAnalyzing)
    case active(any ActiveCoordinateRankAnalyzing)
}
