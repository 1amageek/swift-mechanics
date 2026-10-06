
public struct FiniteStrainKinematics: Sendable {
    public let deformationGradient: Matrix3
    public let greenStrain: SymmetricTensor
    public let volumeRatio: Double

    public init(deformationGradient: Matrix3, domain: StrainDomain) throws(MaterialError) {
        let determinant = try materialCore { () throws(CoreError) in try deformationGradient.determinant() }
        guard determinant >= domain.minimumVolumeRatio else {
            throw .outsideDomain(measure: "volumeRatio", value: determinant, limit: domain.minimumVolumeRatio)
        }
        let twiceStrain = try materialCore { () throws(CoreError) in
            try deformationGradient.transposed().multiplied(by: deformationGradient).subtracting(.identity)
        }
        let strain = try SymmetricTensor.symmetricPart(twiceStrain).scaled(by: 0.5)
        try domain.validate(strain: strain)
        self.deformationGradient = deformationGradient
        greenStrain = strain
        volumeRatio = determinant
    }

    public func strainDirection(for direction: Matrix3) throws(MaterialError) -> SymmetricTensor {
        let product = try materialCore { () throws(CoreError) in try deformationGradient.transposed().multiplied(by: direction) }
        return try .symmetricPart(product)
    }

    /// Maps admitted material stress to finite spatial stresses per reference-volume energy.
    public func response(secondPiolaStress: SymmetricTensor, energyDensity: Double) throws(MaterialError) -> FiniteStressResponse {
        guard energyDensity.isFinite, energyDensity >= 0 else { throw .invalidParameter(name: "finiteStressEnergy") }
        return try stressResponse(secondPiola: secondPiolaStress, energyDensity: energyDensity)
    }

    /// Includes the original deformation and volume derivatives in the stress push-forward.
    public func directionalResponse(deformationDirection: Matrix3, secondPiolaStress: SymmetricTensor,
                                    secondPiolaDirection: SymmetricTensor) throws(MaterialError) -> FiniteStressDirectionalResponse {
        try stressDirection(deformationDirection: deformationDirection, secondPiola: secondPiolaStress,
                            secondPiolaDirection: secondPiolaDirection)
    }

    internal func stressResponse(secondPiola: SymmetricTensor, energyDensity: Double) throws(MaterialError) -> FiniteStressResponse {
        let stress = try secondPiola.matrix()
        let firstPiola = try materialCore { () throws(CoreError) in try deformationGradient.multiplied(by: stress) }
        let cauchy = try materialCore { () throws(CoreError) in
            try firstPiola.multiplied(by: deformationGradient.transposed()).scaled(by: 1 / volumeRatio)
        }
        return FiniteStressResponse(greenStrain: greenStrain, secondPiolaStress: secondPiola,
                                    firstPiolaStress: firstPiola, cauchyStress: cauchy,
                                    energyDensity: try materialFinite(energyDensity, operation: "energyDensity"))
    }

    internal func stressDirection(deformationDirection: Matrix3, secondPiola: SymmetricTensor, secondPiolaDirection: SymmetricTensor) throws(MaterialError) -> FiniteStressDirectionalResponse {
        let f = deformationGradient, h = deformationDirection
        let s = try secondPiola.matrix(), ds = try secondPiolaDirection.matrix()
        let output = try materialCore { () throws(CoreError) in
            let p = try f.multiplied(by: s)
            let dp = try h.multiplied(by: s).adding(f.multiplied(by: ds))
            let inverseTimesDirection = try f.inverted(relativeTolerance: 0).multiplied(by: h)
            let relativeJDirection = inverseTimesDirection.m00 + inverseTimesDirection.m11 + inverseTimesDirection.m22
            let numerator = try dp.multiplied(by: f.transposed()).adding(p.multiplied(by: h.transposed()))
            let cauchy = try p.multiplied(by: f.transposed()).scaled(by: 1 / volumeRatio)
            let dcauchy = try numerator.scaled(by: 1 / volumeRatio).subtracting(cauchy.scaled(by: relativeJDirection))
            return (dp, dcauchy)
        }
        return FiniteStressDirectionalResponse(secondPiolaDirection: secondPiolaDirection,
                                               firstPiolaDirection: output.0, cauchyDirection: output.1)
    }
}
