#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A supported scalar math platform is required.")
#endif

public struct ExactMaxwellEvolution: MaxwellEvolving {
    public init() {}
    public func step(law: MaxwellLaw, accepted: MaxwellState, strainRate: Double, timeStep: Double) throws(MaterialError) -> MaxwellResponse {
        guard accepted.law == law else { throw .incompatibleHistory }
        guard strainRate.isFinite, timeStep.isFinite, timeStep > 0 else { throw .invalidParameter(name: "MaxwellStep") }
        guard abs(strainRate) <= law.maximumStrainRate else {
            throw .outsideDomain(measure: "strainRate", value: abs(strainRate), limit: law.maximumStrainRate)
        }
        let time = try finite(accepted.time + timeStep)
        guard time > accepted.time else { throw .invalidParameter(name: "unrepresentableTimeStep") }
        let z = try finite(law.modulus / law.viscosity * timeStep)
        guard z > 0 else { throw .invalidParameter(name: "unrepresentableRelaxation") }
        let (p1, p2, square) = moments(z)
        let a = try finite((law.modulus * strainRate - law.modulus / law.viscosity * accepted.stress) * timeStep)
        let stress = try finite(z < 0.125 ? accepted.stress + a * p1 :
            law.viscosity * strainRate + (accepted.stress - law.viscosity * strainRate) * exp(-z))
        guard abs(stress) <= law.maximumStress else {
            throw .outsideDomain(measure: "stress", value: abs(stress), limit: law.maximumStress)
        }
        let mean = try finite(accepted.stress + a * p2)
        let integralSquare = try finite(timeStep * (accepted.stress * accepted.stress + 2 * accepted.stress * a * p2 + a * a * square))
        guard integralSquare >= 0 else { throw .nonFiniteResult(operation: "negativeStressSquareIntegral") }
        let loss = try finite(integralSquare / law.viscosity)
        let stored = try finite(stress * (stress / law.modulus) / 2)
        let oldStored = try finite(accepted.stress * (accepted.stress / law.modulus) / 2)
        let input = try finite(strainRate * mean * timeStep)
        let change = try finite(stored - oldStored)
        let residual = try finite(input - change - loss)
        return MaxwellResponse(state: try MaxwellState(law: law, time: time, stress: stress),
            meanStress: mean, storedEnergy: stored, storageChange: change, inputWork: input,
            dissipatedEnergy: loss, energyResidual: residual)
    }
    private func finite(_ x: Double) throws(MaterialError) -> Double {
        guard x.isFinite else { throw .nonFiniteResult(operation: "MaxwellEvolution") }; return x
    }
    // Entire-function moments avoid subtracting nearly equal exponentials.
    private func moments(_ z: Double) -> (Double, Double, Double) {
        if z < 0.125 {
            var t1 = 1.0, t2 = 0.5, power = 4.0
            var p1 = 0.0, p2 = 0.0, square = 0.0
            for n in 0..<16 {
                p1 += t1; p2 += t2; square += t2 * (power - 2) / Double(n + 3)
                t1 *= -z / Double(n + 2); t2 *= -z / Double(n + 3); power *= 2
            }
            return (p1, p2, square)
        }
        let p1 = -expm1(-z) / z
        let p2 = (1 - p1) / z
        let square = (1 - 2 * p1 + (-expm1(-2 * z) / (2 * z))) / z / z
        return (p1, p2, square)
    }
}
