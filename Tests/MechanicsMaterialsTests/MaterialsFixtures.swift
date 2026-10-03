import MechanicsCore
import MechanicsMaterials

enum MaterialsFixtures {
    static func elasticity() throws -> IsotropicElasticity {
        try IsotropicElasticity(bulkModulus: 1000, shearModulus: 400)
    }

    static func domain() throws -> StrainDomain {
        try StrainDomain(maximumStrainNorm: 0.5, minimumVolumeRatio: 0.2)
    }

    static func plasticity(maximumAlpha: Double = 0.1, absoluteTolerance: Double = 1e-9, relativeTolerance: Double = 1e-10) throws -> J2Plasticity {
        try J2Plasticity(elasticity: elasticity(), initialYieldStress: 20, hardeningModulus: 100,
                         maximumAccumulatedPlasticStrain: maximumAlpha,
                         domain: StrainDomain(maximumStrainNorm: 0.2, minimumVolumeRatio: 0.5),
                         residualAbsoluteTolerance: absoluteTolerance, residualRelativeTolerance: relativeTolerance)
    }

    static func close(_ actual: Double, _ expected: Double, absolute: Double = 1e-9, relative: Double = 1e-10) -> Bool {
        abs(actual - expected) <= absolute + relative * abs(expected)
    }

    static func matrixClose(_ actual: Matrix3, _ expected: Matrix3, absolute: Double = 1e-3, relative: Double = 1e-6) throws -> Bool {
        try actual.subtracting(expected).maximumMagnitude <= absolute + relative * expected.maximumMagnitude
    }

    static func tensorClose(_ actual: SymmetricTensor, _ expected: SymmetricTensor, absolute: Double = 1e-9, relative: Double = 1e-10) throws -> Bool {
        try actual.subtracting(expected).norm() <= absolute + relative * expected.norm()
    }

    static func contraction(_ left: Matrix3, _ right: Matrix3) throws -> Double {
        var value = 0.0
        for row in 0..<3 {
            for column in 0..<3 { value += try left.element(row: row, column: column) * right.element(row: row, column: column) }
        }
        return value
    }
}
