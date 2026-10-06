import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ImplicitQualificationPhysics: Sendable {
    public let mass: Double
    public let stiffness: Double
    public let damping: Double
    public let cubicStiffness: Double
    public let constantLoad: Double
    public let law: PolynomialSpringDamper
    public init(mass: Double = 2, stiffness: Double = 8, damping: Double = 0.6,
                cubicStiffness: Double = 0, constantLoad: Double = 1.2) throws(ImplicitMethodsQualificationError) {
        try ImplicitMethodsQualificationFixtures.require(mass.isFinite && mass > 0 && constantLoad.isFinite, "Declared physical mass/load.")
        law = try ImplicitMethodsQualificationFixtures.translated {
            try PolynomialSpringDamper(coordinateKind: .translation, restCoordinate: 0, quadraticStiffness: stiffness,
                quarticStiffness: cubicStiffness, linearDamping: damping, cubicDamping: 0,
                maximumDisplacement: 100, maximumRate: 100)
        }
        self.mass = mass; self.stiffness = stiffness; self.damping = damping
        self.cubicStiffness = cubicStiffness; self.constantLoad = constantLoad
    }
    public func acceleration(q: Double, v: Double) -> Double {
        (constantLoad-stiffness*q-cubicStiffness*q*q*q-damping*v)/mass
    }
    public func originalBalance(q: Double, v: Double, a: Double) -> Double {
        mass*a+stiffness*q+cubicStiffness*q*q*q+damping*v-constantLoad
    }
    public func loadResponse(q: Double, v: Double) throws(RuntimeFailure) -> ScalarLoadResponse {
        do throws(LoadError) {
            var work = LoadWork(budget: try LoadBudget(maximumWork: 1, maximumScalars: 0))
            return try ScalarLoadEvaluator().evaluate(law, coordinate: q, rate: v, work: &work)
        } catch {
            // The provider protocol carries RuntimeFailure; this selected one-evaluation load budget is explicit.
            throw RuntimeFailure(.invalidState, message: "Actual scalar passive-law evaluation failed in the declared physical provider.")
        }
    }
}
