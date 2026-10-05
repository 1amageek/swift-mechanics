#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

public struct ExactBurgersCreepEvolution: BurgersCreepEvolving {
    public init() {}
    public func step(law: BurgersCreepLaw, accepted: BurgersCreepState, appliedStress stress: Double,
                     timeStep dt: Double) throws(MaterialError) -> BurgersCreepResponse {
        guard accepted.law == law else { throw .incompatibleHistory }
        guard stress.isFinite, dt.isFinite, dt > 0 else { throw .invalidParameter(name: "burgersCreepStep") }
        guard abs(stress) <= law.maximumStress else {
            throw .outsideDomain(measure: "stress", value: abs(stress), limit: law.maximumStress)
        }
        let time = try finite(accepted.time+dt)
        guard time > accepted.time else { throw .invalidParameter(name: "unrepresentableTimeStep") }
        let z = try finite(law.kelvinDecay*dt)
        guard z > 0 else { throw .invalidParameter(name: "unrepresentableRelaxation") }
        let equilibrium = try finite(stress/law.kelvinModulus)
        let kelvinIncrement = try finite((equilibrium-accepted.kelvinStrain)*(-expm1(-z)))
        // Keep small increments near the initial state and finite tails near equilibrium.
        let kelvin = try finite(z < 0.125 ? accepted.kelvinStrain+kelvinIncrement :
            equilibrium+(accepted.kelvinStrain-equilibrium)*exp(-z))
        let viscousIncrement = try finite((stress/law.maxwellViscosity)*dt)
        let viscous = try finite(accepted.viscousStrain+viscousIncrement)
        guard abs(kelvin) <= law.maximumKelvinStrain else {
            throw .outsideDomain(measure: "kelvinStrain", value: abs(kelvin), limit: law.maximumKelvinStrain)
        }
        guard abs(viscous) <= law.maximumViscousStrain else {
            throw .outsideDomain(measure: "viscousStrain", value: abs(viscous), limit: law.maximumViscousStrain)
        }
        let elasticStrain = try finite(stress/law.maxwellModulus)
        let jump = try finite(elasticStrain-accepted.appliedStress/law.maxwellModulus)
        let jumpWork = try finite((stress/2+accepted.appliedStress/2)*jump)
        let heldIncrement = try finite(viscousIncrement+kelvinIncrement)
        let heldWork = try finite(stress*heldIncrement)
        let stored = try finite(0.5*stress*elasticStrain+0.5*law.kelvinModulus*kelvin*kelvin)
        let change = try finite(jumpWork+law.kelvinModulus*(accepted.kelvinStrain/2+kelvin/2)*kelvinIncrement)
        let residualStress = try finite(stress-law.kelvinModulus*accepted.kelvinStrain)
        let viscousLoss = try finite(stress*viscousIncrement)
        let kelvinLoss = try finite((residualStress/2)*kelvinIncrement*(1+exp(-z)))
        let loss = try finite(viscousLoss+kelvinLoss)
        guard viscousLoss >= 0, kelvinLoss >= 0 else { throw .nonFiniteResult(operation: "BurgersCreepDissipation") }
        let total = try finite(elasticStrain+viscous+kelvin)
        let rate = try finite(stress/law.maxwellViscosity+(stress-law.kelvinModulus*kelvin)/law.kelvinViscosity)
        let residual = try finite(jumpWork+heldWork-change-loss)
        return BurgersCreepResponse(state: try BurgersCreepState(law: law, time: time, appliedStress: stress,
            kelvinStrain: kelvin, viscousStrain: viscous), totalStrain: total, endpointCreepRate: rate,
            elasticStrainJump: jump, heldStressStrainIncrement: heldIncrement, storedEnergy: stored, storageChange: change,
            stressJumpWork: jumpWork, heldStressWork: heldWork, dissipatedEnergy: loss, energyResidual: residual)
    }
    private func finite(_ value: Double) throws(MaterialError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult(operation: "BurgersCreep") }
        return value
    }
}
