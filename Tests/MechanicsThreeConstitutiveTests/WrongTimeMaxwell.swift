import SwiftMechanics

/// Deliberately violates the supplier time association using an actual shorter physical evolution.
struct WrongTimeMaxwell: MaxwellEvolving {
    func step(law: MaxwellLaw, accepted: MaxwellState, strainRate: Double, timeStep: Double) throws(MaterialError) -> MaxwellResponse {
        try ExactMaxwellEvolution().step(law: law, accepted: accepted, strainRate: strainRate, timeStep: timeStep/2)
    }
}
