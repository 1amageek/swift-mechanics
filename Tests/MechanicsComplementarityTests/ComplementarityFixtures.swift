import SwiftMechanics

enum ComplementarityFixtures {
    static func problem(values: [Double] = [2, -1, -1, 2], b: [Double] = [-1, 1],
                        cone: ConeLayout = .nonnegativeOrthant(dimension: 2), revision: UInt64 = 1,
                        coordinates: [UInt64]? = nil, frameRevision: UInt64 = 1, lawRevision: UInt64 = 1) throws -> ComplementarityProblem {
        try ComplementarityProblem(matrix: DenseMatrix(rows: b.count, columns: b.count, values: values),
            linearTerm: b, cone: cone, identity: ComplementarityIdentity(revision: revision,
                coordinateIDs: coordinates ?? (0..<b.count).map { UInt64($0) },
                frameLayoutRevision: frameRevision, lawRevision: lawRevision))
    }

    static func policy(maximumIterations: Int = 3000, storage: Int = 1000, operations: Int = 2_000_000,
                       iterations: Int = 4000, precision: NumericalPrecision = .float64,
                       backend: NumericalBackend = .referenceCPU) throws -> ComplementarityPolicy {
        try ComplementarityPolicy(precision: precision, backend: backend,
            tolerance: ConeTolerance(absolutePrimal: 1e-9, absoluteDual: 1e-9, absoluteComplementarity: 1e-9,
                absoluteOptimality: 1e-9, relative: 1e-10, primalScale: 1, dualScale: 1),
            maximumIterations: maximumIterations, choleskyPivotThreshold: 1e-14,
            budget: NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: iterations))
    }

    static func work() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 100, arithmeticOperations: 10000, iterations: 0))
    }

    static func close(_ actual: Double, _ expected: Double, absolute: Double = 1e-7, relative: Double = 1e-9) -> Bool {
        abs(actual - expected) <= absolute + relative * abs(expected)
    }
}
