import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsNonlinear
import MechanicsConstraints
import MechanicsJoints
import MechanicsCompiler
import MechanicsLoads
import MechanicsDynamics
import MechanicsEquilibrium

extension FoundationVerification {
    @inline(never) static func verifyEquilibrium() throws {
        let context = try EquilibriumProbeContext()
        try verifyEquilibriumForces(context, scalar: Double.self)
        try verifyEquilibriumStatics(context)
        try verifyEquilibriumSupports(context)
        try verifyEquilibriumContinuation(context)
        try verifyEquilibriumPendulum(context)
    }

    @inline(never) private static func verifyEquilibriumForces<Scalar: NumericalScalar>(_ context: EquilibriumProbeContext, scalar: Scalar.Type) throws {
        let model = try context.spring()
        let forces: any StaticForceEvaluating<Scalar> = ReferenceStaticForceEvaluator<Scalar>()
        var work = NumericalWork(budget: context.budget)
        try forces.validate(model, point: [Scalar(0.2)], parameter: 1, work: &work)
        let gradient = try forces.gradient(model, point: [Scalar(0.2)], parameter: 1, coordinate: 0, work: &work)
        let tangent = try forces.tangent(model, point: [Scalar(0.2)], parameter: 1, row: 0, column: 0, work: &work)
        let input = try forces.parameterDerivative(model, point: [Scalar(0.2)], parameter: 1, coordinate: 0, work: &work)
        let energy = try forces.energy(model, point: [Scalar(0.2)], parameter: 1, work: &work)
        try require(abs(Double(gradient) + 31) < 1e-8 && abs(Double(tangent) - 100) < 1e-8)
        try require(abs(Double(input) + 2) < 1e-8 && abs(Double(energy) + 8.2) < 1e-8)
        var rejected = false
        do throws(StaticForceError) {
            try forces.validate(model, point: [Scalar(4)], parameter: 0, work: &work)
        } catch {
            try require(error == .outsideDomain)
            rejected = true
        }
        try require(rejected)
    }

    @inline(never) private static func verifyEquilibriumStatics(_ context: EquilibriumProbeContext) throws {
        let model = try context.spring()
        let solver: any EquilibriumSolving = ReferenceEquilibriumSolver()
        var work = NumericalWork(budget: context.budget)
        let point = try solver.solve(model, constraints: nil, initialPosition: [0], parameter: 0, time: 0,
            branch: context.branch, policy: context.policy, work: &work)
        try require(abs(point.position[0] - 0.49) < 1e-9 && abs(point.energy + 12.005) < 1e-8)
        try require(abs(100 * point.position[0] - 49) < 1e-7 && abs(point.originalForceResidual[0]) < 1e-7)
        try require(point.generalizedReaction == [0] && point.rank.reactionNullity == 0 && point.work.operations > 0)
        var rejected = false
        do throws(EquilibriumError) {
            _ = try solver.solve(model, constraints: nil, initialPosition: [0], parameter: 11, time: 0,
                branch: context.branch, policy: context.policy, work: &work)
        } catch {
            guard case .outsideDomain = error else { throw FoundationVerificationError.analyticCheckFailed }
            rejected = true
        }
        try require(rejected)
    }

    @inline(never) private static func verifyEquilibriumSupports(_ context: EquilibriumProbeContext) throws {
        let model = try context.spring()
        let supports = try context.supports()
        let solver: any EquilibriumSolving = ReferenceEquilibriumSolver()
        var work = NumericalWork(budget: context.budget)
        let point = try solver.solve(model, constraints: supports, initialPosition: [0], parameter: 0, time: 0,
            branch: context.branch, policy: context.policy, work: &work)
        try require(abs(point.position[0]) < 1e-9 && point.rank.reactionNullity == 1 && point.rowMultipliers[1] == 0)
        try require(abs(point.rowMultipliers[0] - 49) < 1e-8 && abs(point.generalizedReaction[0] + 49) < 1e-8)
        try require(point.originalConstraintResidual.allSatisfy { abs($0) < 1e-8 })
        try require(abs(point.physicalGradient[0] - point.generalizedReaction[0]) < 1e-7)
        let unique = try EquilibriumPolicy(limits: context.limits, nonlinear: context.nonlinear,
            physicalForceTolerances: [1e-7], constraintTolerance: 1e-8, reactionSelection: .requireUnique)
        var rejected = false
        do throws(EquilibriumError) {
            _ = try solver.solve(model, constraints: supports, initialPosition: [0], parameter: 0, time: 0,
                branch: context.branch, policy: unique, work: &work)
        } catch {
            guard case .reactionAmbiguity(let nullity) = error, nullity == 1 else { throw FoundationVerificationError.analyticCheckFailed }
            rejected = true
        }
        try require(rejected)
    }

    @inline(never) private static func verifyEquilibriumContinuation(_ context: EquilibriumProbeContext) throws {
        let model = try context.spring()
        let seed = try EquilibriumContinuationState(model: model, constraints: nil, branch: context.branch,
            position: [0], parameter: 0, time: 0, limits: context.limits)
        let cases = [EquilibriumLoadCase(identity: "prefix", parameter: 0, time: 0),
                     EquilibriumLoadCase(identity: "outside-calibration", parameter: 11, time: 1),
                     EquilibriumLoadCase(identity: "continued", parameter: 1, time: 2)]
        var work = NumericalWork(budget: context.budget)
        let service: any EquilibriumContinuing = ReferenceEquilibriumContinuation()
        let report = try service.sweep(model, constraints: nil, branch: context.branch, state: seed, cases: cases,
            policy: context.policy, work: &work)
        try require(report.acceptedCases == 2 && report.attemptedCases == 2 && abs(report.continuation.position[0] - 0.51) < 1e-9)
        try require(report.cases[1].suppliedSeed == report.cases[2].suppliedSeed && seed.position == [0] && seed.accepted == nil)
        guard case .failed(.outsideDomain) = report.cases[1].status else { throw FoundationVerificationError.analyticCheckFailed }
    }

    @inline(never) private static func verifyEquilibriumPendulum(_ context: EquilibriumProbeContext) throws {
        let model = try context.pendulum()
        let branch = try EquilibriumBranch(identity: "pendulum-small-angle", minimumPosition: [-1], maximumPosition: [1],
            maximumNormalizedStep: 1, limits: context.limits)
        let solver: any EquilibriumSolving = ReferenceEquilibriumSolver()
        var work = NumericalWork(budget: context.budget)
        let point = try solver.solve(model, constraints: nil, initialPosition: [0], parameter: 0, time: 0,
            branch: branch, policy: context.policy, work: &work)
        try require(point.position == [0] && point.energy == 0 && point.originalForceResidual == [0])
        let compiled = try context.compile()
        let mass = try context.mass(compiled, point: point)
        try verifyEquilibriumPendulumLinearization(context, point: point, compiled: compiled, mass: mass)
    }

    @inline(never) private static func verifyEquilibriumPendulumLinearization(_ context: EquilibriumProbeContext, point: EquilibriumSolution,
                                                                           compiled: CompiledMechanicalModel, mass: RigidDynamicsSystem) throws {
        let reduction = EquilibriumReduction(freeCoordinates: 1, basis: [1], damping: [0], outputRows: 1,
            outputMap: [1], outputDimensions: [.angle])
        let policy = try EquilibriumLinearizationPolicy(limits: context.limits,
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            tolerance: LinearTolerance(absoluteResidual: 1e-9, relativeResidual: 1e-10, pivotThreshold: 1e-12),
            displacementProbe: 1e-5, parameterProbe: 1e-5, derivativeAbsoluteTolerances: [1e-5],
            derivativeRelativeTolerance: 1e-6, constraintTolerance: 1e-8, inertialAbsoluteTolerances: [1e-9])
        var work = NumericalWork(budget: context.budget)
        let service: any EquilibriumLinearizing = ReferenceEquilibriumLinearizer()
        let result = try service.linearize(point, compiled: compiled, dynamics: mass, reduction: reduction, policy: policy, work: &work)
        // The independent scalar oscillator is Izz + m*l^2 = 1 + 2 = 3 and K=m*g*l=20.
        let expectedFrequency = (20.0 / 3).squareRoot()
        try require(abs(result.reducedMass[0] - 3) < 1e-10 && abs(result.reducedStiffness[0] - 20) < 1e-10)
        try require(abs(result.stateMatrix[2] + 20.0 / 3) < 1e-9 && abs((-result.stateMatrix[2]).squareRoot() - expectedFrequency) < 1e-9)
        try require(result.stateMatrix[0] == 0 && result.stateMatrix[1] == 1 && result.stateMatrix[3] == 0)
        try require(abs(result.inputMatrix[1] - 1.0 / 3) < 1e-9 && result.outputMatrix == [1, 0])
        try require(result.maximumDirectionalError < 1e-5 && result.maximumInertialError < 1e-9)
    }
}
