/// Caller-owned physical calibration. A nonempty source is provenance, not a certificate.
public struct TireBrushCalibration: Sendable {
    public static let formulation = "radial-brush-v1"
    public let source: String
    public let revision: UInt64
    public let tire: ModelReference
    public let roadSurface: ModelReference
    public let longitudinalStiffness: Double
    public let lateralStiffness: Double
    public let frictionCoefficient: Double
    public let rollingResistanceLength: Double
    public let domain: TireCalibrationDomain

    public init(source: String, revision: UInt64, tire: ModelReference, roadSurface: ModelReference,
                longitudinalStiffness: Double, lateralStiffness: Double, frictionCoefficient: Double,
                rollingResistanceLength: Double, domain: TireCalibrationDomain,
                fittedFormulation: String) throws(TireLawError) {
        guard !source.isEmpty, fittedFormulation == Self.formulation,
              tire.id.kind == .body, roadSurface.id.kind == .material,
              longitudinalStiffness.isFinite, longitudinalStiffness > 0,
              lateralStiffness.isFinite, lateralStiffness > 0,
              frictionCoefficient.isFinite, frictionCoefficient > 0,
              rollingResistanceLength.isFinite, rollingResistanceLength >= 0,
              (frictionCoefficient * domain.minimumNormalLoad).isFinite,
              frictionCoefficient * domain.minimumNormalLoad > 0,
              (frictionCoefficient * domain.maximumNormalLoad).isFinite,
              (rollingResistanceLength * domain.maximumNormalLoad).isFinite,
              (longitudinalStiffness * domain.maximumAbsoluteSlipRatio).isFinite,
              (lateralStiffness * domain.maximumAbsoluteLateralSlipTangent).isFinite else {
            throw .invalidCalibration
        }
        self.source = source; self.revision = revision; self.tire = tire; self.roadSurface = roadSurface
        self.longitudinalStiffness = longitudinalStiffness; self.lateralStiffness = lateralStiffness
        self.frictionCoefficient = frictionCoefficient; self.rollingResistanceLength = rollingResistanceLength
        self.domain = domain
    }
}
