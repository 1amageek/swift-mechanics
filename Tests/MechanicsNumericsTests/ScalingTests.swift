import SwiftMechanics
import Testing

@Suite struct ScalingTests {
    private func budget() throws -> NumericalBudget {
        try NumericalBudget(scalarStorage: 10000, arithmeticOperations: 1000000, iterations: 100)
    }
    private func tolerance() throws -> LinearTolerance<Double> {
        try LinearTolerance(absoluteResidual: 1e-12, relativeResidual: 1e-12, pivotThreshold: 1e-14)
    }
    private func quantity(_ value: Double, _ dimension: PhysicalDimension) throws -> SIReferenceQuantity<Double> {
        try SIReferenceQuantity(magnitude: value, dimension: dimension)
    }

    @Test func dimensionalMixedScaleRecovery() throws {
        // The two equations and two unknowns carry different SI dimensions.
        let matrix = try DenseMatrix<Double>(rows: 2, columns: 2, values: [1e9,2e-3,3e6,4e-6])
        let system = try DimensionalLinearSystem(matrix: matrix, rightHandSide: [6000,14],
            equationDimensions: [.force,.length], unknownDimensions: [.mass,.length])
        let row = try [quantity(1000,.force), quantity(1,.length)]
        let columns = try [quantity(1e-6,.mass), quantity(1e6,.length)]
        let scaler: any EquationScaling<Double> = EquationScaler()
        let scaled = try scaler.scale(system, rowReferences: row, columnReferences: columns, budget: budget())
        #expect(abs((try scaled.matrix.coefficient(row: 0, column: 0))-1) < 1e-12)
        #expect(abs((try scaled.matrix.coefficient(row: 0, column: 1))-2) < 1e-12)
        #expect(abs((try scaled.matrix.coefficient(row: 1, column: 0))-3) < 1e-12)
        #expect(abs((try scaled.matrix.coefficient(row: 1, column: 1))-4) < 1e-12)
        let solved = try ReferenceLinearSolver<Double>().solve(scaled.matrix, rightHandSide: scaled.rightHandSide,
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            tolerance: tolerance(), budget: budget())
        let recovered = try scaled.recover(solved.values, budget: budget())
        #expect(abs(recovered[0]-2e-6) < 1e-18)
        #expect(abs(recovered[1]-2e6) < 1e-6)
        let product = try matrix.applying(recovered, budget: budget())
        for i in 0..<2 { #expect(abs(product[i]-system.rightHandSide[i]) <= 1e-10 + 1e-12*abs(system.rightHandSide[i])) }
        #expect(throws: NumericalError.dimensionMismatch) {
            try scaler.scale(system, rowReferences: [quantity(1000,.mass), quantity(1,.length)], columnReferences: columns, budget: budget())
        }
        #expect(throws: NumericalError.invalidPolicy) {
            try scaler.scale(system, rowReferences: [quantity(0,.force), quantity(1,.length)], columnReferences: columns, budget: budget())
        }
    }

    @Test func explicitRegularizationReportsOriginalModelEffect() throws {
        let matrix = try DenseMatrix<Double>(rows: 2, columns: 2, values: [1,1,1,1])
        let system = try DimensionalLinearSystem(matrix: matrix, rightHandSide: [2,0],
            equationDimensions: [.force,.force], unknownDimensions: [.length,.length])
        let coefficientUnit = try system.coefficientDimension(row: 0, column: 0)
        let delta = try [quantity(0.1,coefficientUnit), quantity(0.1,coefficientUnit)]
        let bounds = try [quantity(0.2,coefficientUnit), quantity(0.2,coefficientUnit)]
        let regularizer: any EquationRegularizing<Double> = DiagonalRegularizer()
        let regularized = try regularizer.addingDiagonal(to: system, perturbation: delta, allowedMagnitude: bounds, budget: budget())
        let solved = try ReferenceLinearSolver<Double>().solve(regularized.matrix, rightHandSide: system.rightHandSide,
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU), tolerance: tolerance(), budget: budget())
        let effect = try regularized.effect(of: solved.values, tolerance: tolerance(), budget: budget())
        #expect(effect.perturbedResidual.isAccepted)
        #expect(!effect.originalResidual.isAccepted)
        #expect(effect.maximumNormalizedPerturbation == 0.5)
        #expect(regularized.diagonalPerturbation[0].dimension == coefficientUnit)
        let originalProduct = try matrix.applying(solved.values, budget: budget())
        for i in 0..<2 {
            #expect(abs(originalProduct[i]-system.rightHandSide[i] + effect.modelEffect[i].magnitude) < 1e-12)
            #expect(effect.modelEffect[i].dimension == .force)
        }
        #expect(throws: NumericalError.perturbationExceeded(value: 0.3, maximum: 0.2)) {
            try regularizer.addingDiagonal(to: system, perturbation: [quantity(0.3,coefficientUnit), quantity(0.1,coefficientUnit)], allowedMagnitude: bounds, budget: budget())
        }
        #expect(throws: NumericalError.dimensionMismatch) {
            try regularizer.addingDiagonal(to: system, perturbation: [quantity(0.1,.mass), quantity(0.1,coefficientUnit)], allowedMagnitude: bounds, budget: budget())
        }
    }
}
