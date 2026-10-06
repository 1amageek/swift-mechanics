/// Principal section axes with zero product of inertia, explicitly declared by the caller.
public struct SpatialBeamSection: Equatable, Sendable {
    public let source: SourceProvenance
    public let area: Double
    public let secondMomentY: Double
    public let secondMomentZ: Double
    public let torsionConstant: Double
    public let shearFactorY: Double
    public let shearFactorZ: Double
    public let outerHalfY: Double
    public let outerHalfZ: Double

    public init(source: SourceProvenance, area: Double, secondMomentY: Double,
                secondMomentZ: Double, torsionConstant: Double, shearFactorY: Double,
                shearFactorZ: Double, outerHalfY: Double, outerHalfZ: Double) throws(SpatialBeamError) {
        for value in [area, secondMomentY, secondMomentZ, torsionConstant, shearFactorY,
                      shearFactorZ, outerHalfY, outerHalfZ] {
            guard value.isFinite, value > 0 else { throw .invalidInput(parameter: "sectionCoefficients") }
        }
        let boundY = area * outerHalfZ * outerHalfZ, boundZ = area * outerHalfY * outerHalfY
        guard boundY.isFinite, boundZ.isFinite, secondMomentY <= boundY, secondMomentZ <= boundZ else {
            throw .invalidInput(parameter: "sectionMomentBounds")
        }
        self.source = source; self.area = area
        self.secondMomentY = secondMomentY; self.secondMomentZ = secondMomentZ
        self.torsionConstant = torsionConstant; self.shearFactorY = shearFactorY; self.shearFactorZ = shearFactorZ
        self.outerHalfY = outerHalfY; self.outerHalfZ = outerHalfZ
    }
}
