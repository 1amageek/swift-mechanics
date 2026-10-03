import MechanicsCore

/// Isotropic Green-strain polynomial; β=0 is St Venant–Kirchhoff.
public struct PolynomialHyperelasticity: Equatable, Sendable, HyperelasticResponding {
    public let elasticity: IsotropicElasticity
    public let nonlinearModulus: Double
    public let domain: StrainDomain

    public init(elasticity: IsotropicElasticity, nonlinearModulus: Double, domain: StrainDomain) throws(MaterialError) {
        guard nonlinearModulus.isFinite, nonlinearModulus >= 0 else { throw .invalidParameter(name: "nonlinearModulus") }
        self.elasticity = elasticity; self.nonlinearModulus = nonlinearModulus; self.domain = domain
    }

    public func evaluate(deformationGradient: Matrix3) throws(MaterialError) -> FiniteStressResponse {
        let kinematics = try FiniteStrainKinematics(deformationGradient: deformationGradient, domain: domain)
        let e = kinematics.greenStrain, squaredNorm = try e.contracted(with: e)
        let factor = try materialFinite(nonlinearModulus * squaredNorm, operation: "hyperelasticStressFactor")
        let stress = try elasticity.tangent(direction: e).adding(e.scaled(by: factor))
        let energy = try materialFinite(try elasticity.energy(strain: e) + 0.25 * factor * squaredNorm, operation: "hyperelasticEnergy")
        return try kinematics.stressResponse(secondPiola: stress, energyDensity: energy)
    }

    public func tangent(deformationGradient: Matrix3, direction: Matrix3) throws(MaterialError) -> FiniteStressDirectionalResponse {
        let kinematics = try FiniteStrainKinematics(deformationGradient: deformationGradient, domain: domain)
        let e = kinematics.greenStrain, de = try kinematics.strainDirection(for: direction)
        let response = try evaluate(deformationGradient: deformationGradient)
        let factor = try materialFinite(nonlinearModulus * (try e.contracted(with: e)), operation: "hyperelasticTangentFactor")
        let cross = try materialFinite(2 * nonlinearModulus * (try e.contracted(with: de)), operation: "hyperelasticTangentCross")
        let ds = try elasticity.tangent(direction: de).adding(de.scaled(by: factor)).adding(e.scaled(by: cross))
        return try kinematics.stressDirection(deformationDirection: direction, secondPiola: response.secondPiolaStress, secondPiolaDirection: ds)
    }
}
