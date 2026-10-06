public struct TerrainSoilCalibration: Equatable, Sendable {
    public static let formulation = "bekker-elastic-janosi-fixed-patch-v1"
    public let source: String
    public let revision: UInt64
    public let material: ModelReference
    public let cohesiveModulus: Double
    public let frictionalModulus: Double
    public let sinkageExponent: Double
    public let unloadingModulus: Double
    public let cohesion: Double
    public let frictionTangent: Double
    public let janosiLength: Double
    public let domain: TerrainCalibrationDomain

    public init(source: String, revision: UInt64, material: ModelReference,
                cohesiveModulus: Double, frictionalModulus: Double, sinkageExponent: Double,
                unloadingModulus: Double, cohesion: Double, frictionTangent: Double,
                janosiLength: Double, domain: TerrainCalibrationDomain,
                fittedFormulation: String) throws(TerrainLawError) {
        guard !source.isEmpty, fittedFormulation == Self.formulation, material.id.kind == .material,
              cohesiveModulus.isFinite, cohesiveModulus >= 0,
              frictionalModulus.isFinite, frictionalModulus >= 0,
              cohesiveModulus > 0 || frictionalModulus > 0,
              sinkageExponent.isFinite, sinkageExponent >= 1,
              unloadingModulus.isFinite, unloadingModulus > 0,
              cohesion.isFinite, cohesion >= 0, frictionTangent.isFinite, frictionTangent >= 0,
              janosiLength.isFinite, janosiLength > 0 else { throw .invalidCalibration }
        let coefficient = try terrainFinite(cohesiveModulus / domain.minimumFootprintWidth + frictionalModulus)
        let slope = try terrainFinite(sinkageExponent * coefficient *
                                      TerrainScalarMath.power(domain.maximumSinkage, sinkageExponent - 1))
        let pressure = try terrainFinite(coefficient * TerrainScalarMath.power(domain.maximumSinkage, sinkageExponent))
        guard coefficient > 0, unloadingModulus > slope, pressure > 0,
              pressure <= domain.maximumPressure,
              (cohesion + frictionTangent * domain.maximumPressure).isFinite else { throw .invalidCalibration }
        self.source = source; self.revision = revision; self.material = material
        self.cohesiveModulus = cohesiveModulus; self.frictionalModulus = frictionalModulus
        self.sinkageExponent = sinkageExponent; self.unloadingModulus = unloadingModulus
        self.cohesion = cohesion; self.frictionTangent = frictionTangent; self.janosiLength = janosiLength
        self.domain = domain
    }
}
