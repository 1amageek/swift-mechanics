public struct SurfaceMaterialPoint: Sendable {
    public let feature: SurfaceFeatureID
    public let barycentric: [Double]
    public init(feature: SurfaceFeatureID, barycentric: [Double], sumTolerance: Double) throws(DeformingContactError) {
        guard barycentric.count == 3, barycentric.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }), sumTolerance.isFinite, sumTolerance >= 0, abs(barycentric.reduce(0,+)-1) <= sumTolerance else { throw .invalidInput }
        self.feature=feature; self.barycentric=barycentric
    }
}
