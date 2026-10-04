public struct TrussPoint: Sendable {
    public let height: Double
    public let downwardLoad: Double
    public let energy: Double
    public let verticalTangent: Double
    public let engineeringStrain: Double
    public let classification: TangentClassification
    public let originalForceResidual: Double
}
