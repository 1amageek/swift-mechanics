public struct ExactStandardLinearSolidEvolution: StandardLinearSolidEvolving {
    private let branchEvolution: any MaxwellEvolving
    public init(branchEvolution: any MaxwellEvolving = ExactMaxwellEvolution()) {
        self.branchEvolution=branchEvolution
    }
    public func step(law: StandardLinearSolidLaw, accepted: StandardLinearSolidState, strainRate: Double,
                     timeStep: Double) throws(MaterialError) -> StandardLinearSolidResponse {
        guard accepted.law == law else { throw .incompatibleHistory }
        guard strainRate.isFinite, timeStep.isFinite, timeStep > 0 else { throw .invalidParameter(name: "standardLinearSolidStep") }
        let increment = try finite(strainRate*timeStep), strain = try finite(accepted.strain + increment)
        guard abs(strain) <= law.maximumStrain else {
            throw .outsideDomain(measure: "strain", value: abs(strain), limit: law.maximumStrain)
        }
        let branch = try branchEvolution.step(law: law.branchLaw, accepted: accepted.branchState,
            strainRate: strainRate, timeStep: timeStep)
        let expectedTime = try finite(accepted.time+timeStep)
        guard branch.state.law == law.branchLaw, branch.state.time == expectedTime else { throw .incompatibleHistory }
        let meanElastic = try finite(law.equilibriumModulus*(accepted.strain/2+strain/2))
        let endpoint = try finite(law.equilibriumModulus*strain+branch.state.stress)
        let mean = try finite(meanElastic+branch.meanStress)
        let storage = try finite(0.5*law.equilibriumModulus*strain*strain+branch.storedEnergy)
        let change = try finite(meanElastic*increment+branch.storageChange)
        let input = try finite(mean*increment)
        let residual = try finite(input-change-branch.dissipatedEnergy)
        return StandardLinearSolidResponse(state: try StandardLinearSolidState(law: law, time: expectedTime,
            strain: strain, branchStress: branch.state.stress), endpointStress: endpoint, meanStress: mean,
            storedEnergy: storage, storageChange: change, inputWork: input,
            dissipatedEnergy: branch.dissipatedEnergy, energyResidual: residual)
    }
    private func finite(_ value: Double) throws(MaterialError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult(operation: "StandardLinearSolid") }
        return value
    }
}
