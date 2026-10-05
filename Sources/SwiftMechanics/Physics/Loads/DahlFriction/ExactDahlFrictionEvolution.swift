#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A supported scalar math platform is required.")
#endif

public struct ExactDahlFrictionEvolution: DahlFrictionEvolving {
    public init() {}
    public func step(law: DahlFrictionLaw, accepted: DahlFrictionState, speed: Double,
                     timeStep dt: Double, work: inout LoadWork) throws(LoadError) -> DahlFrictionResponse {
        try work.reserve(scalars: 40); try work.charge(100)
        guard accepted.law == law else { throw .providerChanged }
        guard speed.isFinite, dt.isFinite, dt > 0 else { throw .invalidInput }
        guard abs(speed) <= law.maximumSpeed else { throw .outsideDomain }
        let time = try finite(accepted.time + dt)
        guard time > accepted.time else { throw .outsideDomain }
        let oldEnergy = try finite(0.5 * law.stiffness * accepted.deflection * accepted.deflection)
        let endpoint: Double, mean: Double, loss: Double
        if speed == 0 { endpoint = accepted.deflection; mean = accepted.deflection; loss = 0 }
        else {
            let decay = try finite(abs(speed) / law.limitingDeflection)
            let z = try finite(decay * dt)
            guard z > 0 else { throw .nonFiniteResult }
            let (f1, f2, square) = moments(z)
            let a = try finite((speed - decay * accepted.deflection) * dt)
            let equilibrium = speed > 0 ? law.limitingDeflection : -law.limitingDeflection
            endpoint = try finite(z < 0.125 ? accepted.deflection + a * f1 :
                equilibrium + (accepted.deflection - equilibrium) * exp(-z))
            mean = try finite(accepted.deflection + a * f2)
            let integralSquare = try finite(dt * (accepted.deflection * accepted.deflection
                + 2 * accepted.deflection * a * f2 + a * a * square))
            guard integralSquare >= 0 else { throw .nonFiniteResult }
            loss = try finite(law.stiffness * decay * integralSquare + law.viscousCoefficient * speed * speed * dt)
        }
        guard abs(endpoint) <= law.limitingDeflection else { throw .outsideDomain }
        let stored = try finite(0.5 * law.stiffness * endpoint * endpoint)
        let change = try finite(stored - oldEnergy)
        let force = try finite(-law.stiffness * endpoint - law.viscousCoefficient * speed)
        let meanForce = try finite(-law.stiffness * mean - law.viscousCoefficient * speed)
        let frictionWork = try finite(meanForce * speed * dt)
        let residual = try finite(frictionWork + change + loss)
        try work.charge(0)
        return DahlFrictionResponse(state: try DahlFrictionState(law: law, time: time, deflection: endpoint),
            endpointForce: force, meanForce: meanForce, storedEnergy: stored, storageChange: change,
            frictionWork: frictionWork, dissipatedEnergy: loss, energyResidual: residual)
    }
    private func finite(_ value: Double) throws(LoadError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
    private func moments(_ z: Double) -> (Double, Double, Double) {
        if z < 0.125 {
            var t1 = 1.0, t2 = 0.5, power = 4.0, f1 = 0.0, f2 = 0.0, square = 0.0
            for n in 0..<16 {
                f1 += t1; f2 += t2; square += t2 * (power - 2) / Double(n + 3)
                t1 *= -z / Double(n + 2); t2 *= -z / Double(n + 3); power *= 2
            }
            return (f1, f2, square)
        }
        let f1 = -expm1(-z) / z
        return (f1, (1-f1)/z, (1-2*f1 + -expm1(-2*z)/(2*z))/z/z)
    }
}
