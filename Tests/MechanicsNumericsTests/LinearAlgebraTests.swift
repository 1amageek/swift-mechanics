import SwiftMechanics
import Testing

@Suite struct LinearAlgebraTests {
    private func budget(storage: Int = 10000, operations: Int = 1000000, iterations: Int = 100) throws -> NumericalBudget {
        try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: iterations)
    }
    private func tolerance() throws -> LinearTolerance<Double> {
        try LinearTolerance(absoluteResidual: 1e-12, relativeResidual: 1e-12, pivotThreshold: 1e-14)
    }
    private func capability(_ algorithm: LinearAlgorithm) -> LinearCapability {
        LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: algorithm)
    }

    @Test func denseSPDAndIndefiniteOriginalEquations() throws {
        let spd = try DenseMatrix<Double>(rows: 3, columns: 3, values: [4,1,0, 1,3,1, 0,1,2])
        // Independent manufactured RHS for x=(1,-2,3): (2,-2,4).
        let solver: any LinearSolving<Double> = ReferenceLinearSolver()
        for algorithm in [LinearAlgorithm.cholesky, .partialPivotLU] {
            let result = try solver.solve(spd, rightHandSide: [2,-2,4], capability: capability(algorithm), tolerance: tolerance(), budget: budget())
            for i in 0..<3 { #expect(abs(result.values[i] - [1.0,-2,3][i]) < 1e-12) }
            #expect(result.termination == .accepted)
            #expect(result.diagnostics.originalResidual.isAccepted)
            #expect(result.diagnostics.numericalRank == 3)
        }
        let saddle = try DenseMatrix<Double>(rows: 2, columns: 2, values: [2,1, 1,0])
        let result = try solver.solve(saddle, rightHandSide: [3,2], capability: capability(.partialPivotLU), tolerance: tolerance(), budget: budget())
        #expect(abs(result.values[0]-2) < 1e-12)
        #expect(abs(result.values[1]+1) < 1e-12)
        #expect(result.diagnostics.factorization == .lu)
        #expect(throws: NumericalError.nonPositiveDefinite(pivot: 1)) {
            try solver.solve(saddle, rightHandSide: [3,2], capability: capability(.cholesky), tolerance: tolerance(), budget: budget())
        }
        let swapped = try DenseMatrix<Double>(rows: 2, columns: 2, values: [0,2, 1,3])
        let pivoted = try solver.solve(swapped, rightHandSide: [4,7], capability: capability(.partialPivotLU), tolerance: tolerance(), budget: budget())
        #expect(pivoted.diagnostics.rowPermutation == [1,0])
        #expect(abs(pivoted.values[0]-1) < 1e-12)
        #expect(abs(pivoted.values[1]-2) < 1e-12)
    }

    @Test func singularRankAndInvalidDomains() throws {
        let solver = ReferenceLinearSolver<Double>()
        let singular = try DenseMatrix<Double>(rows: 3, columns: 3, values: [0,1,2, 0,2,4, 0,0,1])
        #expect(throws: NumericalError.singular(rank: 2, pivot: 0)) {
            try solver.solve(singular, rightHandSide: [1,2,3], capability: capability(.partialPivotLU), tolerance: tolerance(), budget: budget())
        }
        #expect(throws: NumericalError.invalidDimensions) { try DenseMatrix<Double>(rows: Int.max, columns: 2, values: []) }
        #expect(throws: NumericalError.nonFiniteInput) { try DenseMatrix<Double>(rows: 1, columns: 1, values: [.nan]) }
        let nonsymmetric = try DenseMatrix<Double>(rows: 2, columns: 2, values: [2,1, 0,2])
        #expect(throws: NumericalError.nonsymmetric) {
            try solver.solve(nonsymmetric, rightHandSide: [1,1], capability: capability(.cholesky), tolerance: tolerance(), budget: budget())
        }
        #expect(throws: NumericalError.invalidIndex) { try nonsymmetric.coefficient(row: -1, column: 0) }
        #expect(throws: NumericalError.nonFiniteInput) {
            try solver.solve(nonsymmetric, rightHandSide: [1,.infinity], capability: capability(.partialPivotLU), tolerance: tolerance(), budget: budget())
        }
        let overflow = try DenseMatrix<Double>(rows: 1, columns: 1, values: [.greatestFiniteMagnitude])
        #expect(throws: NumericalError.nonFiniteResult) { try overflow.applying([2], budget: budget()) }
    }

    @Test func csrOperatorAndCGMatchDenseOracle() throws {
        let sparse = try CSRMatrix<Double>(rows: 3, columns: 3, rowOffsets: [0,2,5,7], columnIndices: [0,1,0,1,2,1,2], values: [4,1,1,3,1,1,2])
        let op: any LinearOperating<Double> = sparse
        #expect(try op.applying([1,-2,3], budget: budget()) == [2,-2,4])
        let result = try ReferenceLinearSolver<Double>().solve(sparse, rightHandSide: [2,-2,4], capability: capability(.conjugateGradient), tolerance: tolerance(), budget: budget())
        for i in 0..<3 { #expect(abs(result.values[i] - [1.0,-2,3][i]) < 1e-12) }
        #expect(result.diagnostics.originalResidual.isAccepted)
        #expect(result.diagnostics.work.iterations > 1 && result.diagnostics.work.iterations <= 3)
        #expect(result.diagnostics.factorization == .none)
        #expect(sparse.values.count == 7)
        #expect(throws: NumericalError.invalidCSR) {
            try CSRMatrix<Double>(rows: 1, columns: 2, rowOffsets: [0,2], columnIndices: [1,1], values: [1,1])
        }
        #expect(throws: NumericalError.invalidCSR) {
            try CSRMatrix<Double>(rows: 2, columns: 2, rowOffsets: [0,3,1], columnIndices: [0], values: [1])
        }
        let indefinite = try CSRMatrix<Double>(rows: 2, columns: 2, rowOffsets: [0,1,2], columnIndices: [0,1], values: [1,-1])
        #expect(throws: NumericalError.nonPositiveDefinite(pivot: 1)) {
            try ReferenceLinearSolver<Double>().solve(indefinite, rightHandSide: [0,1], capability: capability(.conjugateGradient), tolerance: tolerance(), budget: budget())
        }
        let uncertified = try CSRMatrix<Double>(rows: 2, columns: 2, rowOffsets: [0,2,4], columnIndices: [0,1,0,1], values: [1,2,2,1])
        #expect(throws: NumericalError.unsupportedCapability) {
            try ReferenceLinearSolver<Double>().solve(uncertified, rightHandSide: [0,0], capability: capability(.conjugateGradient), tolerance: tolerance(), budget: budget())
        }
        let hiddenNegative = try CSRMatrix<Double>(rows: 2, columns: 2, rowOffsets: [0,1,2], columnIndices: [0,1], values: [-1,1])
        #expect(throws: NumericalError.nonPositiveDefinite(pivot: 0)) {
            try ReferenceLinearSolver<Double>().solve(hiddenNegative, rightHandSide: [0,1], capability: capability(.conjugateGradient), tolerance: tolerance(), budget: budget())
        }
        let zero = try ReferenceLinearSolver<Double>().solve(sparse, rightHandSide: [0,0,0], capability: capability(.conjugateGradient), tolerance: tolerance(), budget: budget(iterations: 0))
        #expect(zero.values == [0,0,0])
        #expect(zero.diagnostics.originalResidual.infinityNorm == 0)
    }

    @Test func explicitFloat32DifferentialAndCapabilityRejection() throws {
        let matrix32 = try DenseMatrix<Float>(rows: 2, columns: 2, values: [1.1,0.3,0.3,2.7])
        let matrix64 = try DenseMatrix<Double>(rows: 2, columns: 2, values: [1.1,0.3,0.3,2.7])
        let result32 = try ReferenceLinearSolver<Float>().solve(matrix32, rightHandSide: [0.2, -1.7],
            capability: LinearCapability(precision: .float32, backend: .referenceCPU, algorithm: .cholesky),
            tolerance: LinearTolerance(absoluteResidual: 1e-6, relativeResidual: 1e-6, pivotThreshold: 1e-7), budget: budget())
        let result64 = try ReferenceLinearSolver<Double>().solve(matrix64, rightHandSide: [0.2,-1.7], capability: capability(.cholesky), tolerance: tolerance(), budget: budget())
        for i in 0..<2 { #expect(abs(Double(result32.values[i])-result64.values[i]) < 1e-6) }
        #expect(result32.diagnostics.capability.precision == .float32)
        #expect(throws: NumericalError.unsupportedCapability) {
            try ReferenceLinearSolver<Float>().solve(matrix32, rightHandSide: [1,1], capability: capability(.cholesky),
                tolerance: LinearTolerance(absoluteResidual: 1e-6, relativeResidual: 1e-6, pivotThreshold: 1e-7), budget: budget())
        }
        #expect(throws: NumericalError.unsupportedCapability) {
            try ReferenceLinearSolver<Double>().solve(matrix64, rightHandSide: [1,1],
                capability: LinearCapability(precision: .float64, backend: .acceleratedDevice, algorithm: .partialPivotLU),
                tolerance: tolerance(), budget: budget())
        }
    }

    @Test func callerBudgetsRejectWithoutPartialSuccess() throws {
        let matrix = try DenseMatrix<Double>(rows: 2, columns: 2, values: [2,0,0,3])
        let solver = ReferenceLinearSolver<Double>()
        #expect(throws: NumericalError.resourceLimit(resource: .scalarStorage, limit: 1)) {
            try solver.solve(matrix, rightHandSide: [2,3], capability: capability(.partialPivotLU), tolerance: tolerance(), budget: budget(storage: 1))
        }
        #expect(throws: NumericalError.resourceLimit(resource: .arithmeticOperations, limit: 0)) {
            try solver.solve(matrix, rightHandSide: [2,3], capability: capability(.partialPivotLU), tolerance: tolerance(), budget: budget(operations: 0))
        }
        #expect(throws: NumericalError.resourceLimit(resource: .iterations, limit: 0)) {
            try solver.solve(matrix, rightHandSide: [2,3], capability: capability(.partialPivotLU), tolerance: tolerance(), budget: budget(iterations: 0))
        }
        let sparse = try CSRMatrix<Double>(rows: 2, columns: 2, rowOffsets: [0,1,2], columnIndices: [0,1], values: [2,3])
        #expect(throws: NumericalError.resourceLimit(resource: .iterations, limit: 1)) {
            try solver.solve(sparse, rightHandSide: [2,3], capability: capability(.conjugateGradient), tolerance: tolerance(), budget: budget(iterations: 1))
        }
    }

    @Test func cancellationPropagates() async throws {
        let matrix = try DenseMatrix<Double>(rows: 1, columns: 1, values: [1])
        let gate = AsyncStream<Void>.makeStream()
        let task = Task { () -> NumericalError? in
            for await _ in gate.stream { break }
            do {
                _ = try ReferenceLinearSolver<Double>().solve(matrix, rightHandSide: [1], capability: capability(.partialPivotLU), tolerance: tolerance(), budget: budget())
                return nil
            } catch let error as NumericalError { return error }
            catch { return nil }
        }
        task.cancel(); gate.continuation.finish()
        #expect(await task.value == .cancelled)
    }
}
