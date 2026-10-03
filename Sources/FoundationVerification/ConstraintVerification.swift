import MechanicsCore
import MechanicsNumerics
import MechanicsNonlinear
import MechanicsJoints
import MechanicsConstraints

extension FoundationVerification {
    @inline(never) static func verifyConstraints() throws {
        try verifyCircleAssembly()
        try verifyConstraintProjection()
        try verifyScalarJointPower()
    }

    @inline(never) private static func constraintPolicy() throws -> ConstraintSolvePolicy {
        let budget = try NumericalBudget(scalarStorage: 100_000, arithmeticOperations: 2_000_000, iterations: 1000)
        let tolerance = try LinearTolerance<Double>(absoluteResidual: 1e-10, relativeResidual: 0, pivotThreshold: 1e-13)
        let nonlinear = try NonlinearPolicy<Double>(strategy: .lineSearch(contraction: 0.5, sufficientDecrease: 1e-4, minimumFraction: 1e-7),
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU), tolerance: tolerance,
            referenceScale: 1, minimumDirectionNorm: 0, derivativeProbeDistance: 1e-6, derivativeAbsoluteTolerance: 1e-4,
            derivativeRelativeTolerance: 1e-4, maximumFactorEntries: 1000, estimateCondition: false, budget: budget)
        return try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 3, maximumRows: 2, expectedLayoutRevision: 7),
            diagonalMetric: [1, 4], energyScale: 5, rankPolicy: .allowRedundancy, rankRelativeTolerance: 1e-10,
            originalResidualTolerance: 1e-8, maximumCorrection: 10, nonlinear: nonlinear,
            linearCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky), linearTolerance: tolerance)
    }

    @inline(never) private static func constraintSystem(_ rows: [QuadraticConstraint]) throws -> QuadraticConstraintSystem {
        let layout = try ConstraintCoordinateLayout(coordinateIDs: [1, 2], dimensions: [.length, .length], scales: [1, 1], timeScale: 1, revision: 7)
        return try QuadraticConstraintSystem(layout: layout, rows: rows, minimumPosition: [-10, -10], maximumPosition: [10, 10], minimumTime: -10, maximumTime: 10)
    }

    @inline(never) private static func constraintWork() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 100_000, arithmeticOperations: 2_000_000, iterations: 1000))
    }

    @inline(never) private static func verifyCircleAssembly() throws {
        let system = try constraintSystem([
            QuadraticConstraint(id: 1, constant: -1, linear: [0, 0], hessian: [2, 0, 0, 2], timeLinear: 0, timeQuadratic: 0, mixedTime: [0, 0]),
            QuadraticConstraint(id: 2, constant: 0, linear: [-2, 0], hessian: [2, 0, 0, 2], timeLinear: 0, timeQuadratic: 0, mixedTime: [0, 0])])
        let service: any ConstraintAssembling = WeightedConstraintAssembler()
        let policy = try constraintPolicy()
        for sign in [-1.0, 1.0] {
            var work = try constraintWork()
            let result = try service.assemble(system, initialPosition: [0.7, sign * 0.6], time: 0, policy: policy, work: &work)
            let x = result.position[0], y = result.position[1]
            try require(abs(x - 0.5) < 1e-7 && y * sign > 0)
            try require(abs(x*x + y*y - 1) < 1e-8 && abs((x-1)*(x-1) + y*y - 1) < 1e-8)
            try require(result.rank.rank == 2 && result.physicalIntroducedWork == nil)
        }
    }

    @inline(never) private static func verifyConstraintProjection() throws {
        let first = QuadraticConstraint(id: 1, constant: -1, linear: [1, 1], hessian: [0, 0, 0, 0], timeLinear: 0, timeQuadratic: 0, mixedTime: [0, 0])
        let second = QuadraticConstraint(id: 2, constant: -2, linear: [2, 2], hessian: [0, 0, 0, 0], timeLinear: 0, timeQuadratic: 0, mixedTime: [0, 0])
        let system = try constraintSystem([first, second]), policy = try constraintPolicy()
        let service: any ConstraintAssembling = WeightedConstraintAssembler()
        var work = try constraintWork(), linearWork = try constraintWork()
        let evaluator: any ConstraintEvaluating = QuadraticConstraintEvaluator()
        let evaluation = try evaluator.evaluate(system, position: [0.8, 0.2], velocity: [1, 0], time: 0, policy: policy.evaluation, work: &work)
        let sample = VelocityConstraintSample(layout: system.layout, rowIDs: evaluation.rowIDs, rows: evaluation.jacobian,
            drift: evaluation.timeDerivative, accelerationBias: evaluation.accelerationBias, isIntegrable: true)
        let result = try service.projectVelocity(sample, initialVelocity: [1, 0], policy: policy, work: &work, linearWork: &linearWork)
        try require(abs(result.velocity[0] - 0.2) < 1e-9 && abs(result.velocity[1] + 0.2) < 1e-9)
        try require(abs(result.introducedKineticEnergy + 2) < 1e-9 && result.originalResidual < 1e-8)
        try require(result.rank.rank == 1 && !result.rank.reactionsUnique)
        let contradictory = QuadraticConstraint(id: 2, constant: -4, linear: [2, 2], hessian: [0, 0, 0, 0], timeLinear: 0, timeQuadratic: 0, mixedTime: [0, 0])
        let inconsistentSystem = try constraintSystem([first, contradictory])
        var rejected = false
        do throws(ConstraintError) {
            _ = try service.assemble(inconsistentSystem, initialPosition: [0, 0], time: 0, policy: policy, work: &work)
        } catch {
            switch error { case .inconsistent(let row, let residual): try require(row == 2 && residual > 0.9); rejected = true
            default: throw FoundationVerificationError.unexpectedFailure }
        }
        try require(rejected)
    }

    @inline(never) private static func verifyScalarJointPower() throws {
        let joint = try JointManifold(.revolute(axis: .unitZ))
        let law = try ScalarJointLaw(referencePosition: 0.2, stiffness: 10, damping: 3, coulombEffort: 2, minimumPosition: -10, maximumPosition: 10)
        let service: any ScalarJointPortEvaluating = ScalarJointPortEvaluator()
        var work = try constraintWork()
        let result = try service.passive(joint, position: 0.7, velocity: -0.4, law: law, wrap: .unwrapped, policy: constraintPolicy().evaluation, work: &work)
        try require(abs(result.smoothEffort + 3.8) < 1e-10 && abs(result.potentialEnergy - 1.25) < 1e-10)
        try require(abs(result.damperPower + 0.48) < 1e-10)
        switch result.friction { case .sliding(let effort, let power): try require(effort == 2 && power == -0.8)
        default: throw FoundationVerificationError.unexpectedFailure }
    }
}
