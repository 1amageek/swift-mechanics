import MechanicsNumerics
public struct TrussCriticalPoint: Sendable {
    public let model: NonlinearTruss
    public let point: TrussPoint
    public let lowerHeight: Double
    public let upperHeight: Double
    public let loadUncertaintyBound: Double
    public let normalizedTangentResidual: Double
    public let work: NumericalWork
}
