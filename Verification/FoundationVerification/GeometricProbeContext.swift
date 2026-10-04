import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
enum GeometricProbeContext {
    @inline(never)
    static func system(_ fixture: FourBarProbeModel) throws -> GeometricConstraintSystem {
        let layout = try ConstraintCoordinateLayout(coordinateIDs: [101, 102, 103],
            dimensions: [.angle, .angle, .angle], scales: [2, 3, 4], timeScale: 2, revision: 1)
        let first = try GeometricFrameEndpoint(body: fixture.coupler,
            frame: EntityID(kind: .frame, key: fixture.coupler.key + "-frame"), point: Vector3(2, 0, 0))
        let second = try GeometricFrameEndpoint(body: fixture.rocker,
            frame: EntityID(kind: .frame, key: fixture.rocker.key + "-frame"), point: Vector3(2, 0, 0))
        let relation = try GeometricRelation(kind: .coincidence, rowIDs: [1, 2, 3], first: first,
            second: second, target: GeometricAnalyticTarget(), scale: 2)
        var work = try work()
        return try GeometricConstraintSystem(model: fixture.model, layout: layout, relations: [relation],
            minimumPosition: [-5, -5, -5], maximumPosition: [5, 5, 5], minimumTime: 0, maximumTime: 10,
            capacity: GeometricConstraintCapacity(maximumBodies: 4, maximumPositions: 3,
                maximumVelocities: 3, maximumRows: 3, maximumMetadataBytes: 32768), work: &work)
    }

    static func work() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 1_000_000,
            arithmeticOperations: 20_000_000, iterations: 1000))
    }

    static func policy(limit: Double = 1, cancelled: Bool = false) throws -> ManifoldProjectionPolicy {
        let base = try MechanismProbeContext.policy().constraints
        let constraints = try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(
                maximumCoordinates: 3, maximumRows: 3, expectedLayoutRevision: 1, isCancelled: { cancelled }),
            diagonalMetric: [1, 2, 3], energyScale: 7, rankPolicy: .allowRedundancy,
            rankRelativeTolerance: 1e-10, originalResidualTolerance: 1e-9,
            maximumCorrection: limit, nonlinear: base.nonlinear,
            linearCapability: base.linearCapability, linearTolerance: base.linearTolerance)
        return try ManifoldProjectionPolicy(constraints: constraints, maximumIterations: 30,
            maximumPathCorrection: limit, maximumMetadataBytes: 4096)
    }
}
