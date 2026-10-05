#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A supported scalar math platform is required.")
#endif

public struct ExactDCMotorEvolution: ExactMotorEvolving {
    public init() {}
    public func step(parameters p: ExactMotorParameters, accepted: ExactMotorState, voltage: Double,
                     speed: Double, timeStep dt: Double, work: inout ActuationWork) throws(ActuationError) -> ExactMotorResponse {
        try work.reserve(scalars: 40); try work.charge(100)
        guard accepted.parameters == p else { throw .staleBinding }
        guard voltage.isFinite, speed.isFinite, dt.isFinite, dt > 0 else { throw .invalidInput }
        guard abs(voltage) <= p.maximumVoltage, abs(speed) <= p.maximumSpeed else { throw .outsideDomain }
        let time = try finite(accepted.time + dt)
        guard time > accepted.time else { throw .staleTime }
        let z = try finite(p.resistance / p.inductance * dt)
        let (f1, f2, square) = moments(z)
        let a = try finite(((voltage - p.reciprocalConstant * speed - p.resistance * accepted.current) / p.inductance) * dt)
        let current: Double
        if z >= 0.125 {
            let equilibrium = try finite((voltage - p.reciprocalConstant * speed) / p.resistance)
            current = try finite(equilibrium + (accepted.current - equilibrium) * exp(-z))
        } else { current = try finite(accepted.current + a * f1) }
        guard abs(current) <= p.maximumCurrent else { throw .outsideDomain }
        let mean = try finite(accepted.current + a * f2)
        let integral = try finite(mean * dt)
        let integralSquare = try finite(dt * (accepted.current * accepted.current + 2 * accepted.current * a * f2 + a * a * square))
        guard integralSquare >= 0 else { throw .nonfiniteResult }
        let source = try finite(voltage * integral)
        let copper = try finite(p.resistance * integralSquare)
        let viscous = try finite(p.damping * speed * speed * dt)
        let shaft = try finite(p.reciprocalConstant * speed * integral - viscous)
        let stored = try finite(p.inductance * current * current / 2)
        let oldStored = try finite(p.inductance * accepted.current * accepted.current / 2)
        let change = try finite(stored - oldStored)
        let torque = try finite(p.reciprocalConstant * mean - p.damping * speed)
        let residual = try finite(source - shaft - copper - viscous - change)
        try work.charge(0)
        return ExactMotorResponse(state: try ExactMotorState(parameters: p, time: time, current: current),
            meanCurrent: mean, meanTorque: torque, magneticEnergy: stored, storageChange: change,
            sourceWork: source, shaftWork: shaft, copperLoss: copper, viscousLoss: viscous, energyResidual: residual)
    }
    private func finite(_ x: Double) throws(ActuationError) -> Double {
        guard x.isFinite else { throw .nonfiniteResult }; return x
    }
    private func moments(_ z: Double) -> (Double, Double, Double) {
        if z < 0.125 {
            var t1 = 1.0, t2 = 0.5, power = 4.0
            var f1 = 0.0, f2 = 0.0, square = 0.0
            for n in 0..<16 {
                f1 += t1; f2 += t2; square += t2 * (power - 2) / Double(n + 3)
                t1 *= -z / Double(n + 2); t2 *= -z / Double(n + 3); power *= 2
            }
            return (f1, f2, square)
        }
        let f1 = -expm1(-z) / z
        return (f1, (1 - f1) / z, (1 - 2 * f1 + -expm1(-2 * z) / (2 * z)) / z / z)
    }
}
