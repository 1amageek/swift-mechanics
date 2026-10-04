/// Caller-selected calibrated envelope, with dimensionless Green strain and J.
public struct StrainDomain: Equatable, Sendable {
    public let maximumStrainNorm: Double
    public let minimumVolumeRatio: Double

    public init(maximumStrainNorm: Double, minimumVolumeRatio: Double) throws(MaterialError) {
        guard maximumStrainNorm.isFinite, maximumStrainNorm > 0 else {
            throw .invalidParameter(name: "maximumStrainNorm")
        }
        guard minimumVolumeRatio.isFinite, minimumVolumeRatio > 0, minimumVolumeRatio <= 1 else {
            throw .invalidParameter(name: "minimumVolumeRatio")
        }
        self.maximumStrainNorm = maximumStrainNorm
        self.minimumVolumeRatio = minimumVolumeRatio
    }

    public func validate(strain: SymmetricTensor) throws(MaterialError) {
        let norm = try strain.norm()
        guard norm <= maximumStrainNorm else {
            throw .outsideDomain(measure: "strainNorm", value: norm, limit: maximumStrainNorm)
        }
    }
}
