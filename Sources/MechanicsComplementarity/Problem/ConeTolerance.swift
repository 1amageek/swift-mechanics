import MechanicsNumerics

public struct ConeTolerance: Equatable, Sendable {
    public let primalThreshold: Double
    public let dualThreshold: Double
    public let complementarityThreshold: Double
    public let optimalityThreshold: Double

    public init(absolutePrimal: Double, absoluteDual: Double, absoluteComplementarity: Double,
                absoluteOptimality: Double, relative: Double, primalScale: Double, dualScale: Double) throws(ComplementarityError) {
        guard absolutePrimal.isFinite, absolutePrimal >= 0, absoluteDual.isFinite, absoluteDual >= 0,
              absoluteComplementarity.isFinite, absoluteComplementarity >= 0,
              absoluteOptimality.isFinite, absoluteOptimality >= 0, relative.isFinite, relative >= 0,
              primalScale.isFinite, primalScale > 0, dualScale.isFinite, dualScale > 0 else {
            throw .numerical(.invalidPolicy)
        }
        primalThreshold = try complementarityFinite(absolutePrimal + relative * primalScale)
        dualThreshold = try complementarityFinite(absoluteDual + relative * dualScale)
        complementarityThreshold = try complementarityFinite(absoluteComplementarity + relative * (try complementarityFinite(primalScale * dualScale)))
        optimalityThreshold = try complementarityFinite(absoluteOptimality + relative * primalScale)
    }
}
