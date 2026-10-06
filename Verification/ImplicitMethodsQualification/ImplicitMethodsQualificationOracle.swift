import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public enum ImplicitMethodsQualificationOracle {
    public static func euler(_ physics: ImplicitQualificationPhysics, q: Double, v: Double, h: Double) -> (q: Double, v: Double, a: Double) {
        let nextV = (physics.mass*v+h*(physics.constantLoad-physics.stiffness*q))/(physics.mass+physics.damping*h+physics.stiffness*h*h)
        let nextQ = q+h*nextV
        return (nextQ, nextV, physics.acceleration(q: nextQ, v: nextV))
    }
    public static func nonlinearEuler(_ physics: ImplicitQualificationPhysics, q: Double, v: Double, h: Double)
        throws(ImplicitMethodsQualificationError) -> (q: Double, v: Double, a: Double) {
        func balance(_ candidate: Double) -> Double {
            physics.originalBalance(q: q+h*candidate, v: candidate, a: (candidate-v)/h)
        }
        var lower = -100.0, upper = 100.0
        try ImplicitMethodsQualificationFixtures.require(balance(lower) < 0 && balance(upper) > 0, "Independent nonlinear Euler physical root bracket.")
        for _ in 0..<120 { let middle = (lower+upper)/2; if balance(middle) > 0 { upper = middle } else { lower = middle } }
        let nextV = (lower+upper)/2, nextQ = q+h*nextV
        return (nextQ, nextV, physics.acceleration(q: nextQ, v: nextV))
    }
    public static func structural(_ physics: ImplicitQualificationPhysics, q: Double, v: Double, a: Double,
                                  h: Double, parameters p: GeneralizedAlphaParameters) -> (q: Double, v: Double, a: Double) {
        let predictedQ = q+h*v+h*h*(0.5-p.beta)*a
        let predictedV = v+h*(1-p.gamma)*a
        let inertiaWeight = p.method == .hht ? 1 : 1-p.alphaM
        let previousInertia = p.method == .hht ? 0 : physics.mass*p.alphaM*a
        let coefficient = physics.mass*inertiaWeight+(1-p.alphaF)*(physics.stiffness*p.beta*h*h+physics.damping*p.gamma*h)
        let constant = previousInertia+physics.stiffness*((1-p.alphaF)*predictedQ+p.alphaF*q)
            + physics.damping*((1-p.alphaF)*predictedV+p.alphaF*v)-physics.constantLoad
        let nextA = -constant/coefficient
        return (predictedQ+p.beta*h*h*nextA, predictedV+p.gamma*h*nextA, nextA)
    }
    public static func nonlinearHHT(_ physics: ImplicitQualificationPhysics, q: Double, v: Double, a: Double,
                                     h: Double, parameters p: GeneralizedAlphaParameters)
        throws(ImplicitMethodsQualificationError) -> (q: Double, v: Double, a: Double) {
        let predictedQ = q+h*v+h*h*(0.5-p.beta)*a
        let predictedV = v+h*(1-p.gamma)*a
        func balance(_ candidate: Double) -> Double {
            let nextQ = predictedQ+p.beta*h*h*candidate, nextV = predictedV+p.gamma*h*candidate
            return (1-p.alphaF)*physics.originalBalance(q: nextQ, v: nextV, a: candidate)
                + p.alphaF*physics.originalBalance(q: q, v: v, a: candidate)
        }
        var lower = -100.0, upper = 100.0
        try ImplicitMethodsQualificationFixtures.require(balance(lower) < 0 && balance(upper) > 0, "Independent monotone physical HHT root bracket.")
        for _ in 0..<120 { let middle = (lower+upper)/2; if balance(middle) > 0 { upper = middle } else { lower = middle } }
        let nextA = (lower+upper)/2
        return (predictedQ+p.beta*h*h*nextA, predictedV+p.gamma*h*nextA, nextA)
    }
    public static func oscillatorAtOne() -> (q: Double, v: Double) {
        var cosine = 1.0, sine = 1.0, ct = 1.0, st = 1.0
        for i in 1...24 { ct *= -1/Double((2*i-1)*(2*i)); st *= -1/Double((2*i)*(2*i+1)); cosine += ct; sine += st }
        return (cosine, -sine)
    }
    public static func energy(_ physics: ImplicitQualificationPhysics, q: Double, v: Double) -> Double {
        let equilibrium = physics.constantLoad/physics.stiffness
        return physics.mass*v*v/2+physics.stiffness*(q-equilibrium)*(q-equilibrium)/2
    }
}
