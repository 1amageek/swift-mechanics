
/// Bounded additive Green-strain J2 radial return with isotropic hardening.
public struct J2Plasticity: Equatable, Sendable, PlasticResponding {
    public let elasticity: IsotropicElasticity
    public let initialYieldStress: Double
    public let hardeningModulus: Double
    public let maximumAccumulatedPlasticStrain: Double
    public let domain: StrainDomain
    public let residualAbsoluteTolerance: Double
    public let residualRelativeTolerance: Double

    public init(elasticity: IsotropicElasticity, initialYieldStress: Double, hardeningModulus: Double,
                maximumAccumulatedPlasticStrain: Double, domain: StrainDomain,
                residualAbsoluteTolerance: Double, residualRelativeTolerance: Double) throws(MaterialError) {
        guard initialYieldStress.isFinite, initialYieldStress > 0 else { throw .invalidParameter(name: "initialYieldStress") }
        guard hardeningModulus.isFinite, hardeningModulus >= 0 else { throw .invalidParameter(name: "hardeningModulus") }
        guard maximumAccumulatedPlasticStrain.isFinite, maximumAccumulatedPlasticStrain > 0 else {
            throw .invalidParameter(name: "maximumAccumulatedPlasticStrain")
        }
        guard residualAbsoluteTolerance.isFinite, residualAbsoluteTolerance > 0,
              residualRelativeTolerance.isFinite, residualRelativeTolerance >= 0 else {
            throw .invalidParameter(name: "yieldResidualTolerance")
        }
        self.elasticity = elasticity; self.initialYieldStress = initialYieldStress
        self.hardeningModulus = hardeningModulus
        self.maximumAccumulatedPlasticStrain = maximumAccumulatedPlasticStrain; self.domain = domain
        self.residualAbsoluteTolerance = residualAbsoluteTolerance
        self.residualRelativeTolerance = residualRelativeTolerance
        _ = try materialFinite(3 * elasticity.shearModulus + hardeningModulus, operation: "returnModulus")
        _ = try materialFinite(initialYieldStress + hardeningModulus * maximumAccumulatedPlasticStrain, operation: "maximumYieldStress")
    }

    public func initialHistory() -> PlasticHistory {
        PlasticHistory(material: self, plasticGreenStrain: .zero, accumulatedPlasticStrain: 0)
    }

    private func predictor(greenStrain: SymmetricTensor, acceptedHistory: PlasticHistory) throws(MaterialError) -> (stress: SymmetricTensor, q: Double) {
        guard acceptedHistory.material == self else { throw .incompatibleHistory }
        try domain.validate(strain: greenStrain)
        let deviator = try greenStrain.subtracting(acceptedHistory.plasticGreenStrain).deviator()
        let stress = try deviator.scaled(by: 2 * elasticity.shearModulus)
        let q = try materialFinite(1.5.squareRoot() * (try stress.norm()), operation: "equivalentTrialStress")
        return (stress, q)
    }

    public func evaluate(greenStrain: SymmetricTensor, acceptedHistory: PlasticHistory) throws(MaterialError) -> PlasticTrial {
        let trial = try predictor(greenStrain: greenStrain, acceptedHistory: acceptedHistory)
        let oldAlpha = acceptedHistory.accumulatedPlasticStrain
        let oldYield = try materialFinite(initialYieldStress + hardeningModulus * oldAlpha, operation: "yieldStress")
        let isPlastic = trial.q > oldYield
        let increment = isPlastic ? (trial.q - oldYield) / (3 * elasticity.shearModulus + hardeningModulus) : 0
        let alpha = try materialFinite(oldAlpha + increment, operation: "accumulatedPlasticStrain")
        guard alpha <= maximumAccumulatedPlasticStrain else {
            throw .outsideDomain(measure: "accumulatedPlasticStrain", value: alpha, limit: maximumAccumulatedPlasticStrain)
        }
        let plasticStrain: SymmetricTensor
        if isPlastic {
            // Multiplying the bounded scalar ratio avoids an overflow-prone 1/q.
            let plasticIncrement = try trial.stress.scaled(by: 1.5 * increment / trial.q)
            plasticStrain = try acceptedHistory.plasticGreenStrain.adding(plasticIncrement)
        } else {
            plasticStrain = acceptedHistory.plasticGreenStrain
        }
        let elasticStrain = try greenStrain.subtracting(plasticStrain)
        let stress = try elasticity.tangent(direction: elasticStrain)
        let equivalentStress = try materialFinite(1.5.squareRoot() * (try stress.deviator().norm()), operation: "equivalentReturnedStress")
        let newYield = try materialFinite(initialYieldStress + hardeningModulus * alpha, operation: "returnedYieldStress")
        let residual = isPlastic ? abs(equivalentStress - newYield) : max(0, equivalentStress - newYield)
        let tolerance = try materialFinite(residualAbsoluteTolerance + residualRelativeTolerance * max(trial.q, newYield), operation: "yieldAcceptanceTolerance")
        guard residual <= tolerance else { throw .nonConvergence(residual: residual, tolerance: tolerance) }
        let energy = try materialFinite(try elasticity.energy(strain: elasticStrain) + 0.5 * hardeningModulus * alpha * alpha, operation: "plasticStoredEnergy")
        let dissipation = try materialFinite(initialYieldStress * increment + 0.5 * hardeningModulus * increment * increment, operation: "plasticDissipation")
        let history = PlasticHistory(material: self, plasticGreenStrain: plasticStrain, accumulatedPlasticStrain: alpha)
        return PlasticTrial(history: history, secondPiolaStress: stress, energyDensity: energy,
                            dissipationIncrement: dissipation, plasticMultiplierIncrement: increment,
                            yieldResidual: residual, isPlastic: isPlastic)
    }

    /// Derivative of the selected branch with accepted history held fixed.
    public func tangent(greenStrain: SymmetricTensor, direction: SymmetricTensor, acceptedHistory: PlasticHistory) throws(MaterialError) -> SymmetricTensor {
        let returned = try evaluate(greenStrain: greenStrain, acceptedHistory: acceptedHistory)
        if !returned.isPlastic { return try elasticity.tangent(direction: direction) }
        let trial = try predictor(greenStrain: greenStrain, acceptedHistory: acceptedHistory)
        let mu = elasticity.shearModulus, gamma = returned.plasticMultiplierIncrement
        let dsTrial = try direction.deviator().scaled(by: 2 * mu)
        let unit = try trial.stress.scaled(by: 1 / trial.q)
        let dq = try materialFinite(1.5 * (try unit.contracted(with: dsTrial)), operation: "equivalentStressDirection")
        let dgamma = dq / (3 * mu + hardeningModulus)
        let a = 1 - 3 * mu * gamma / trial.q
        // Equivalent to (-3μ dγ/q+3μγ dq/q²) strial without q².
        let radial = try materialFinite(-3 * mu * dgamma + 3 * mu * gamma * (dq / trial.q), operation: "radialTangent")
        let deviatorDirection = try dsTrial.scaled(by: a).adding(unit.scaled(by: radial))
        let pressureDirection = try materialFinite(elasticity.bulkModulus * (try direction.trace()), operation: "plasticPressureDirection")
        return try deviatorDirection.adding(.isotropic(pressureDirection))
    }

    public func evaluate(deformationGradient: Matrix3, acceptedHistory: PlasticHistory) throws(MaterialError) -> PlasticFiniteTrial {
        let kinematics = try FiniteStrainKinematics(deformationGradient: deformationGradient, domain: domain)
        let trial = try evaluate(greenStrain: kinematics.greenStrain, acceptedHistory: acceptedHistory)
        let response = try kinematics.stressResponse(secondPiola: trial.secondPiolaStress, energyDensity: trial.energyDensity)
        return PlasticFiniteTrial(constitutive: trial, response: response)
    }

    public func tangent(deformationGradient: Matrix3, direction: Matrix3, acceptedHistory: PlasticHistory) throws(MaterialError) -> FiniteStressDirectionalResponse {
        let kinematics = try FiniteStrainKinematics(deformationGradient: deformationGradient, domain: domain)
        let trial = try evaluate(greenStrain: kinematics.greenStrain, acceptedHistory: acceptedHistory)
        let de = try kinematics.strainDirection(for: direction)
        let ds = try tangent(greenStrain: kinematics.greenStrain, direction: de, acceptedHistory: acceptedHistory)
        return try kinematics.stressDirection(deformationDirection: direction, secondPiola: trial.secondPiolaStress, secondPiolaDirection: ds)
    }
}
