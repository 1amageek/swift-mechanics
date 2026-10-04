public struct HybridPolicy: Equatable, Sendable {
    public let maximumContacts: Int
    public let maximumColliders: Int
    public let maximumBodies: Int
    public let maximumVelocities: Int
    public let maximumIdentifierBytes: Int
    public let lengthTolerance: Double
    public let normalTolerance: Double
    public let speedTolerance: Double
    public let independenceTolerance: Double
    public let impulseScales: [Double]
    public let momentumAbsolute: Double
    public let momentumRelative: Double
    public let energyAbsolute: Double
    public let energyRelative: Double
    public init(maximumContacts: Int, maximumColliders: Int, maximumBodies: Int, maximumVelocities: Int,
                maximumIdentifierBytes: Int, lengthTolerance: Double, normalTolerance: Double, speedTolerance: Double,
                independenceTolerance: Double, impulseScales: [Double], momentumAbsolute: Double, momentumRelative: Double,
                energyAbsolute: Double, energyRelative: Double) throws(HybridError) {
        guard maximumContacts > 0, maximumColliders > 0, maximumBodies > 0, maximumVelocities > 0,
              maximumIdentifierBytes > 0, impulseScales.count <= maximumVelocities,
              impulseScales.allSatisfy({ $0.isFinite && $0 > 0 }),
              [lengthTolerance,normalTolerance,speedTolerance,momentumAbsolute,momentumRelative,energyAbsolute,energyRelative].allSatisfy({ $0.isFinite && $0 >= 0 }),
              independenceTolerance.isFinite, independenceTolerance >= 0, independenceTolerance < 1 else { throw .invalidInput }
        self.maximumContacts=maximumContacts; self.maximumColliders=maximumColliders; self.maximumBodies=maximumBodies
        self.maximumVelocities=maximumVelocities; self.maximumIdentifierBytes=maximumIdentifierBytes
        self.lengthTolerance=lengthTolerance; self.normalTolerance=normalTolerance; self.speedTolerance=speedTolerance
        self.independenceTolerance=independenceTolerance; self.impulseScales=impulseScales
        self.momentumAbsolute=momentumAbsolute; self.momentumRelative=momentumRelative
        self.energyAbsolute=energyAbsolute; self.energyRelative=energyRelative
    }
}
