import SwiftMechanics
import Testing

@Suite struct ReductionTests {
    private func budget(iterations: Int = 200) throws -> NumericalBudget {
        try NumericalBudget(scalarStorage: 10000, arithmeticOperations: 1000000, iterations: iterations)
    }
    private func tolerance() throws -> LinearTolerance<Double> {
        try LinearTolerance(absoluteResidual: 1e-12, relativeResidual: 1e-12, pivotThreshold: 1e-14)
    }
    private func capability(_ algorithm: LinearAlgorithm) -> LinearCapability {
        LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: algorithm)
    }

    @Test func branchingTreeMatchesIndependentDenseAssembly() throws {
        // Coordinate order: root, child of root, second child of root, child of first child.
        let tree = try TreeLinearSystem<Double>(parents: [-1,0,0,1], diagonal: [5,4,3,2], edges: [0,-1,0.5,-0.25])
        let dense = try DenseMatrix<Double>(rows: 4, columns: 4, values: [5,-1,0.5,0, -1,4,0,-0.25, 0.5,0,3,0, 0,-0.25,0,2])
        // Independently assembled b for x=(1,2,-1,3).
        let rhs = [2.5,6.25,-2.5,5.5]
        let reduced: any TreeLinearSolving<Double> = TreeLinearSolver()
        let solution = try reduced.solve(tree, rightHandSide: rhs, capability: capability(.treeElimination), tolerance: tolerance(), budget: budget())
        let oracle = try ReferenceLinearSolver<Double>().solve(dense, rightHandSide: rhs, capability: capability(.partialPivotLU), tolerance: tolerance(), budget: budget())
        for i in 0..<4 {
            #expect(abs(solution.values[i]-oracle.values[i]) < 1e-12)
            #expect(abs(solution.values[i]-[1.0,2,-1,3][i]) < 1e-12)
        }
        #expect(solution.diagnostics.originalResidual.isAccepted)
        #expect(solution.diagnostics.ordering == .suppliedTree)
        #expect(try tree.applying([1,2,-1,3], budget: budget()) == rhs)
        #expect(solution.diagnostics.work.operations <= 20*tree.count)
        #expect(solution.diagnostics.work.peakScalarStorage == 8*tree.count)
        #expect(throws: NumericalError.invalidTree(node: 2)) {
            try TreeLinearSystem<Double>(parents: [-1,0,2], diagonal: [1,1,1], edges: [0,1,1])
        }
        let singular = try TreeLinearSystem<Double>(parents: [-1,0], diagonal: [1,1], edges: [0,1])
        #expect(throws: NumericalError.eliminationBreakdown(pivot: 0)) {
            try reduced.solve(singular, rightHandSide: [1,1], capability: capability(.treeElimination), tolerance: tolerance(), budget: budget())
        }
    }

    @Test func schurAndRecoveryPreserveBlockCoordinates() throws {
        let a = try DenseMatrix<Double>(rows: 2, columns: 2, values: [2,0,0,4])
        let b = try DenseMatrix<Double>(rows: 2, columns: 1, values: [1,2])
        let c = try DenseMatrix<Double>(rows: 1, columns: 2, values: [1,2])
        let d = try DenseMatrix<Double>(rows: 1, columns: 1, values: [0])
        // x=(3,-1), y=2 -> f=(8,0), g=1; Schur=-1.5 and reduced rhs=-3.
        let solver: any SchurSolving<Double> = SchurSolver()
        let result = try solver.solve(a: a, b: b, c: c, d: d, primalRightHandSide: [8,0], reducedRightHandSide: [1],
            capability: capability(.partialPivotLU), tolerance: tolerance(), budget: budget())
        #expect(abs(result.primal[0]-3) < 1e-12)
        #expect(abs(result.primal[1]+1) < 1e-12)
        #expect(abs(result.reduced[0]-2) < 1e-12)
        #expect(try result.schur.coefficient(row: 0, column: 0) == -1.5)
        #expect(result.primalResidual.isAccepted && result.reducedResidual.isAccepted)
        let assembled = try DenseMatrix<Double>(rows: 3, columns: 3, values: [2,0,1, 0,4,2, 1,2,0])
        let oracle = try ReferenceLinearSolver<Double>().solve(assembled, rightHandSide: [8,0,1], capability: capability(.partialPivotLU), tolerance: tolerance(), budget: budget())
        #expect(abs(result.primal[0]-oracle.values[0]) < 1e-12)
        #expect(abs(result.primal[1]-oracle.values[1]) < 1e-12)
        #expect(abs(result.reduced[0]-oracle.values[2]) < 1e-12)
        let dependentD = try DenseMatrix<Double>(rows: 1, columns: 1, values: [1.5])
        #expect(throws: NumericalError.singular(rank: 0, pivot: 0)) {
            try solver.solve(a: a, b: b, c: c, d: dependentD, primalRightHandSide: [8,0], reducedRightHandSide: [1],
                capability: capability(.partialPivotLU), tolerance: tolerance(), budget: budget())
        }
        #expect(throws: NumericalError.resourceLimit(resource: .iterations, limit: 0)) {
            try solver.solve(a: a, b: b, c: c, d: d, primalRightHandSide: [8,0], reducedRightHandSide: [1],
                capability: capability(.partialPivotLU), tolerance: tolerance(), budget: budget(iterations: 0))
        }
    }
}
