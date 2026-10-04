import SwiftMechanics

@main
struct FoundationVerification {
    static func main() throws(FoundationVerificationError) {
        do {
            try verify()
            try verifyNumericalExtensions()
            try verifyKinematics()
            try verifyLoads()
            try verifyCompiler()
            try verifyMachines()
            try verifyCollision()
            try verifyDynamics()
            try verifyFlexible()
            try verifyContactLaws()
            try verifyMaterialSites()
            try verifyContactResponse()
            try verifyExchange()
            try verifyConstraints()
            if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) { try verifyGeometricConstraints() }
            try verifyTransmissions()
            try verifyEquilibrium()
            try verifyContactPatches()
            try verifyDeformingContact()
            try verifyStructuralAnalysis()
            try verifyDerivatives()
            try verifyOptimization()
            try verifyGranular()
            try verifyPlanarFluids()
            if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) { try verifyRuntime(); try verifyRuntimeReplacement(); try verifyMechanisms(); try verifyNonlinearMechanisms(); try verifySleepMechanisms(); try verifyReactionPaths(); try verifyTopologyContinuation(); try verifyFluids(); try verifyPlanarRuntime(); try verifyIntegration(); try verifyActuation(); try verifyHybrid() }
            else { throw FoundationVerificationError.unexpectedFailure }
        } catch {
            throw .unexpectedFailure
        }
        print("Foundation runtime verification passed: inertia, solves, materials, kinematics, loads, compiler, collision, dynamics, tetrahedra, contact laws, coupled response, runtime transactions, explicit integration and native model exchange.")
    }

    static func require(_ condition: Bool) throws(FoundationVerificationError) {
        guard condition else { throw .analyticCheckFailed }
    }

    private static func verify() throws {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let policy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 1e-12)
        let massCalculator: any MassPropertyCalculating = AnalyticMassCalculator()
        let mass = try massCalculator.properties(of: .box(width: 2, depth: 3, height: 4), density: 5, policy: policy)
        try require(abs(mass.mass - 120) < 1e-10 && abs(mass.inertiaAtCenter.m00 - 250) < 1e-10)
        try require(abs(mass.inertiaAtCenter.m11 - 200) < 1e-10 && abs(mass.inertiaAtCenter.m22 - 130) < 1e-10)
        var invalidMassRejected = false
        do {
            _ = try massCalculator.properties(of: .sphere(radius: 1), density: -1, policy: policy)
        } catch {
            invalidMassRejected = true
        }
        try require(invalidMassRejected)

        let state = BaseState.spatial(pose: .identity, worldLinearVelocity: .zero, bodyAngularVelocity: .unitZ)
        let coordinates = try BaseLayout.spatialFloating.encode(state)
        try require(coordinates.q.count == 7 && coordinates.v.count == 6)
        try require(try BaseLayout.spatialFloating.decode(coordinates, quaternionTolerance: tolerance) == state)

        let budget = try NumericalBudget(scalarStorage: 10000, arithmeticOperations: 100000, iterations: 32)
        let linearTolerance = try LinearTolerance<Double>(absoluteResidual: 1e-9, relativeResidual: 1e-10, pivotThreshold: 1e-12)
        let lu = LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU)
        let solver: any LinearSolving<Double> = ReferenceLinearSolver<Double>()
        let i = mass.inertiaAtCenter
        let inertia = try DenseMatrix<Double>(rows: 3, columns: 3, values: [i.m00, i.m01, i.m02, i.m10, i.m11, i.m12, i.m20, i.m21, i.m22])
        let result = try solver.solve(inertia, rightHandSide: [250, -400, 390], capability: lu, tolerance: linearTolerance, budget: budget)
        try require(abs(result.values[0] - 1) < 1e-10 && abs(result.values[1] + 2) < 1e-10 && abs(result.values[2] - 3) < 1e-10)
        let csr = try CSRMatrix<Double>(rows: 3, columns: 3, rowOffsets: [0, 1, 2, 3], columnIndices: [0, 1, 2], values: [250, 200, 130])
        let cg = LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .conjugateGradient)
        let sparse = try solver.solve(csr, rightHandSide: [250, -400, 390], capability: cg, tolerance: linearTolerance, budget: budget)
        try require(abs(sparse.values[0] - 1) < 1e-9 && abs(sparse.values[1] + 2) < 1e-9 && abs(sparse.values[2] - 3) < 1e-9)
        let floatSolver: any LinearSolving<Float> = ReferenceLinearSolver<Float>()
        let floatMatrix = try DenseMatrix<Float>(rows: 2, columns: 2, values: [4, 1, 1, 3])
        let floatTolerance = try LinearTolerance<Float>(absoluteResidual: 1e-5, relativeResidual: 1e-5, pivotThreshold: 1e-7)
        let floatResult = try floatSolver.solve(floatMatrix, rightHandSide: [6, 7], capability: LinearCapability(precision: .float32, backend: .referenceCPU, algorithm: .cholesky), tolerance: floatTolerance, budget: budget)
        try require(abs(floatResult.values[0] - 1) < 1e-5 && abs(floatResult.values[1] - 2) < 1e-5)
        var incompatiblePrecisionRejected = false
        do throws(NumericalError) {
            _ = try floatSolver.solve(floatMatrix, rightHandSide: [6, 7], capability: lu, tolerance: floatTolerance, budget: budget)
        } catch {
            try require(error == .unsupportedCapability)
            incompatiblePrecisionRejected = true
        }
        try require(incompatiblePrecisionRejected)
        let tree = try TreeLinearSystem<Double>(parents: [-1, 0, 0], diagonal: [4, 3, 5], edges: [0, 1, 2])
        let treeSolver: any TreeLinearSolving<Double> = TreeLinearSolver<Double>()
        let treeResult = try treeSolver.solve(tree, rightHandSide: [4, 7, -3], capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .treeElimination), tolerance: linearTolerance, budget: budget)
        try require(abs(treeResult.values[0] - 1) < 1e-10 && abs(treeResult.values[1] - 2) < 1e-10 && abs(treeResult.values[2] + 1) < 1e-10)
        let schurSolver: any SchurSolving<Double> = SchurSolver<Double>()
        let a = try DenseMatrix<Double>(rows: 1, columns: 1, values: [2])
        let b = try DenseMatrix<Double>(rows: 1, columns: 1, values: [1])
        let d = try DenseMatrix<Double>(rows: 1, columns: 1, values: [0])
        let reduced = try schurSolver.solve(a: a, b: b, c: b, d: d, primalRightHandSide: [0], reducedRightHandSide: [1], capability: lu, tolerance: linearTolerance, budget: budget)
        try require(abs(reduced.primal[0] - 1) < 1e-10 && abs(reduced.reduced[0] + 2) < 1e-10)
        let dimensioned = try DimensionalLinearSystem(matrix: a, rightHandSide: [6.0], equationDimensions: [.force], unknownDimensions: [.acceleration])
        let scaler: any EquationScaling<Double> = EquationScaler<Double>()
        let scaled = try scaler.scale(dimensioned, rowReferences: [SIReferenceQuantity(magnitude: 3, dimension: .force)], columnReferences: [SIReferenceQuantity(magnitude: 2, dimension: .acceleration)], budget: budget)
        let scaledResult = try solver.solve(scaled.matrix, rightHandSide: scaled.rightHandSide, capability: lu, tolerance: linearTolerance, budget: budget)
        let physicalResult = try scaled.recover(scaledResult.values, budget: budget)
        try require(abs(physicalResult[0] - 3) < 1e-10)
        let regularizer: any EquationRegularizing<Double> = DiagonalRegularizer<Double>()
        let regularized = try regularizer.addingDiagonal(to: dimensioned, perturbation: [SIReferenceQuantity(magnitude: 1, dimension: .mass)], allowedMagnitude: [SIReferenceQuantity(magnitude: 1, dimension: .mass)], budget: budget)
        let changedResult = try solver.solve(regularized.matrix, rightHandSide: dimensioned.rightHandSide, capability: lu, tolerance: linearTolerance, budget: budget)
        let effect = try regularized.effect(of: changedResult.values, tolerance: linearTolerance, budget: budget)
        try require(abs(changedResult.values[0] - 2) < 1e-10 && abs(effect.originalResidual.infinityNorm - 2) < 1e-10)
        try require(effect.perturbedResidual.isAccepted && abs(effect.modelEffect[0].magnitude - 2) < 1e-10)

        let elasticity = try IsotropicElasticity(bulkModulus: 1000, shearModulus: 400)
        let domain = try StrainDomain(maximumStrainNorm: 0.5, minimumVolumeRatio: 0.2)
        let linearMaterial: any LinearElasticResponding = elasticity
        let elastic = try linearMaterial.evaluate(strain: SymmetricTensor(xx: 0.01, yy: 0, zz: 0), domain: domain)
        try require(abs(elastic.stress.xx - (46.0 / 3)) < 1e-10)
        let hyperelastic: any HyperelasticResponding = try PolynomialHyperelasticity(elasticity: elasticity, nonlinearModulus: 800, domain: domain)
        let f = try Matrix3(1.1, 0, 0, 0, 1, 0, 0, 0, 1)
        let response = try hyperelastic.evaluate(deformationGradient: f)
        try require(abs(response.secondPiolaStress.xx - 161.9261) < 1e-8)
        try require(abs(response.energyDensity - 8.476810125) < 1e-8)
        let rotation = try UnitQuaternion(axis: .unitZ, angle: .pi / 2).matrix()
        let rotated = try hyperelastic.evaluate(deformationGradient: rotation.multiplied(by: f))
        try require(abs(rotated.secondPiolaStress.xx - response.secondPiolaStress.xx) < 1e-8)
        let plastic: any PlasticResponding = try J2Plasticity(elasticity: elasticity, initialYieldStress: 20, hardeningModulus: 100, maximumAccumulatedPlasticStrain: 0.1, domain: domain, residualAbsoluteTolerance: 1e-9, residualRelativeTolerance: 1e-10)
        let accepted = plastic.initialHistory()
        let trial = try plastic.evaluate(greenStrain: SymmetricTensor(xx: 0.04, yy: -0.02, zz: -0.02), acceptedHistory: accepted)
        try require(trial.isPlastic && trial.dissipationIncrement > 0 && trial.history.accumulatedPlasticStrain > 0)
        try require(accepted.accumulatedPlasticStrain == 0 && trial.yieldResidual < 1e-8)
        _ = try plastic.tangent(greenStrain: SymmetricTensor(xx: 0.04, yy: -0.02, zz: -0.02), direction: SymmetricTensor(xx: 1, yy: 0, zz: 0), acceptedHistory: accepted)
    }
}
