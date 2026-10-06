import SwiftMechanics

public enum LinearQuadraticQualificationFixture {
    public static func policy(operations: Int = 50_000_000, storage: Int = 1_000_000, iterations: Int = 20_000,
        riccati: Int = 1000, cancelled: @escaping @Sendable () -> Bool = { false }) throws -> LinearQuadraticPolicy {
        try LinearQuadraticPolicy(maximumStates: 2, maximumInputs: 2, maximumMetadataBytes: 256, maximumRiccatiIterations: riccati,
            tolerance: LinearTolerance(absoluteResidual: 1e-11, relativeResidual: 1e-11, pivotThreshold: 1e-13),
            semidefiniteTolerance: 1e-12, symmetryTolerance: 1e-10,
            budget: NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: iterations), isCancelled: cancelled)
    }
    public static func work(_ policy: LinearQuadraticPolicy, seeded: Bool = false) throws -> NumericalWork {
        var result = NumericalWork(budget: policy.budget)
        if seeded { try result.chargeOperations(11); try result.requireStorage(17); try result.advanceIteration() }
        return result
    }
    public static func analytic(a: [Double] = [1], b: [Double] = [1], states: Int = 1, inputs: Int = 1,
        identity: String = "lqr-independent-scalar", stateScales: [Double]? = nil, inputScales: [Double]? = nil) throws -> DiscreteControlSystem {
        let policy = try self.policy()
        var work = try self.work(policy)
        let scales: [Double], inputsScale: [Double]
        if let stateScales { scales = stateScales } else { scales = [Double](repeating: 1, count: states) }
        if let inputScales { inputsScale = inputScales } else { inputsScale = [Double](repeating: 1, count: inputs) }
        let preparer: any DiscreteControlSystemPreparing = ReferenceDiscreteControlSystemPreparer()
        return try preparer.analytic(identity: identity, samplePeriodSeconds: 0.1,
            stateDimensions: [PhysicalDimension](repeating: .length, count: states),
            inputDimensions: [PhysicalDimension](repeating: .force, count: inputs), stateScales: scales, inputScales: inputsScale,
            stateMatrix: a, inputMatrix: b, policy: policy, work: &work)
    }
    public static func design(_ system: DiscreteControlSystem, q: [Double] = [1], r: [Double] = [1],
                               witness: [Double] = [0.5]) throws -> LinearQuadraticDesign {
        let policy = try self.policy()
        var work = try self.work(policy)
        let designer: any LinearQuadraticDesigning = ReferenceLinearQuadraticDesigner()
        return try designer.design(system, stateCost: q, inputCost: r, stabilizingGainWitness: witness, policy: policy, work: &work)
    }
}
