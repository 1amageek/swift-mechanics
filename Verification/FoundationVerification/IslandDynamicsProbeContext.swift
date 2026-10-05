import SwiftMechanics

/// Immutable public composition; every invocation receives its own bounded numerical/load work.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class IslandDynamicsProbeContext: Sendable {
    let source: IslandDynamicsProbeModel
    let policy: StationaryIslandPolicy
    let program: StationaryIslandProgram
    let constructionWork: StationaryIslandWork
    let thresholds: MechanismSleepPolicy
    let numericalBudget: NumericalBudget
    let loadBudget: LoadBudget

    @inline(never)
    init(source: IslandDynamicsProbeModel? = nil, firstDrive: Double = 2, secondDrive: Double = 2) throws {
        let original: IslandDynamicsProbeModel
        if let source { original = source } else { original = try IslandDynamicsProbeModel() }
        let selected = try Self.makePolicy()
        let budget = try NumericalBudget(scalarStorage: 1_000_000, arithmeticOperations: 100_000_000, iterations: 10_000)
        let loads = try LoadBudget(maximumWork: 1_000_000, maximumScalars: 100_000)
        var work = StationaryIslandWork(numerical: NumericalWork(budget: budget), loads: LoadWork(budget: loads))
        let prepared = try Self.prepare(original, drive: original.drive(first: firstDrive, second: secondDrive),
            policy: selected, work: &work)
        self.source = original; policy = selected; program = prepared; constructionWork = work
        numericalBudget = budget; loadBudget = loads
        thresholds = try MechanismSleepPolicy(maximumCoordinates: 3, kineticEnergyThreshold: 1e-12,
            normalizedVelocityThreshold: 1e-12)
    }

    func makeWork() -> StationaryIslandWork {
        StationaryIslandWork(numerical: NumericalWork(budget: numericalBudget), loads: LoadWork(budget: loadBudget))
    }

    @inline(never)
    func motion(_ island: StationaryMechanicalIsland, physical: KinematicState,
                work: inout StationaryIslandWork) throws -> StationaryIslandMotion {
        let computing: any StationaryIslandComputing = ReferenceStationaryIslandDynamics()
        return try computing.motion(program: program, islandID: island.id, physical: physical, work: &work)
    }

    @inline(never)
    func rest(_ island: StationaryMechanicalIsland, physical: KinematicState,
              work: inout StationaryIslandWork) throws -> StationaryIslandRestCertificate? {
        let computing: any StationaryIslandComputing = ReferenceStationaryIslandDynamics()
        return try computing.certifyRest(program: program, islandID: island.id, physical: physical,
            thresholds: thresholds, work: &work)
    }

    @inline(never)
    func associate(_ certificate: StationaryIslandRestCertificate, physical: KinematicState,
                   work: inout StationaryIslandWork) throws -> Bool {
        let computing: any StationaryIslandComputing = ReferenceStationaryIslandDynamics()
        return try computing.associateRest(certificate: certificate, program: program, physical: physical, work: &work)
    }

    @inline(never)
    static func prepare(_ source: IslandDynamicsProbeModel, drive: [Double], policy: StationaryIslandPolicy,
                        work: inout StationaryIslandWork) throws -> StationaryIslandProgram {
        let preparing: any StationaryIslandPreparing = ReferenceStationaryIslandPreparer()
        return try preparing.prepare(source: source.model, constraints: source.constraints, drive: drive,
            policy: policy, work: &work)
    }

    @inline(never)
    static func makePolicy(maximumIslands: Int = 3, isCancelled: @escaping @Sendable () -> Bool = { false }) throws -> StationaryIslandPolicy {
        let tolerance = try LinearTolerance<Double>(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-12)
        let lu = LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU)
        let nonlinear = try NonlinearPolicy<Double>(strategy: .newton, capability: lu, tolerance: tolerance,
            referenceScale: 1, minimumDirectionNorm: 0, derivativeProbeDistance: 1e-6,
            derivativeAbsoluteTolerance: 1e-5, derivativeRelativeTolerance: 1e-5, maximumFactorEntries: 100,
            estimateCondition: false, budget: NumericalBudget(scalarStorage: 100_000, arithmeticOperations: 10_000_000, iterations: 1000))
        let constraints = try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 3,
            maximumRows: 3, expectedLayoutRevision: 1), diagonalMetric: [1, 1, 1], energyScale: 1,
            rankPolicy: .requireIndependentRows, rankRelativeTolerance: 1e-10, originalResidualTolerance: 1e-9,
            maximumCorrection: 10, nonlinear: nonlinear, linearCapability: lu, linearTolerance: tolerance)
        let dynamics = try DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            linearTolerance: tolerance, coordinateScales: [1, 1, 1], energyScale: 1, timeScale: 2)
        let mechanics = try MechanismSolvePolicy(dynamics: dynamics, constraints: constraints,
            maximumCoordinates: 3, maximumRows: 3, originalTolerance: 1e-9, isCancelled: isCancelled)
        let velocity = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let admission = DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 4, maximumVelocities: 3,
            maximumBodyWrenches: 0, maximumGeneralizedContributions: 0), angularVelocityTolerance: velocity,
            linearVelocityTolerance: velocity, isCancelled: isCancelled)
        return try StationaryIslandPolicy(maximumIslands: maximumIslands, maximumSignatureBytes: 100_000,
            maximumIdentifierBytes: 256, maximumCompilationCalls: 3, mechanics: mechanics, admission: admission)
    }
}
