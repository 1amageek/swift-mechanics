/// Shared original section laws for both endpoint traction acceptance and public fields.
internal enum SpatialBeamSectionLaw {
    static func evaluate(_ assembly: SpatialBeamAssembly, shape: SpatialBeamInterpolation,
                         q: [Double]) throws(SpatialBeamError) -> (strain: [Double], resultant: [Double], energyPerLength: Double) {
        var strain = [Double](repeating: 0, count: 6), resultant = strain, energy = 0.0
        for row in 0..<6 {
            strain[row] = try SpatialBeamAlgebra.dot(shape.strain, offset: row * 12, q)
            resultant[row] = try SpatialBeamAlgebra.finite(assembly.constitutiveDiagonal[row] * strain[row])
            energy = try SpatialBeamAlgebra.finite(energy + SpatialBeamAlgebra.weightedSquare(strain[row], coefficient: assembly.constitutiveDiagonal[row], weight: 0.5))
        }
        if assembly.beam.formulation == .eulerBernoulli {
            // Vy=-Mz', Vz=My'. Constitutive shear strains and their energy remain zero.
            let kyPrime = try SpatialBeamAlgebra.dot(shape.curvatureGradient, q)
            let kzPrime = try SpatialBeamAlgebra.dot(shape.curvatureGradient, offset: 12, q)
            resultant[1] = try SpatialBeamAlgebra.finite(-assembly.constitutiveDiagonal[5] * kzPrime)
            resultant[2] = try SpatialBeamAlgebra.finite(assembly.constitutiveDiagonal[4] * kyPrime)
        }
        return (strain, resultant, energy)
    }
}
