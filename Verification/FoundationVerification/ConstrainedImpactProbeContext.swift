import SwiftMechanics

/// Immutable real impact inputs; cancellation and solve ledgers belong to each caller operation.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class ConstrainedImpactProbeContext: Sendable {
    let source: ConstrainedImpactProbeModel
    let input: HardImpactInput
    let policy: ConstrainedImpactPolicy
    let budget: NumericalBudget
    let collisionConstructionWork: CollisionWork
    let pairingConstructionWork: ContactWork
    private let contactBudget: ContactBudget
    private let velocityTolerance: NumericalTolerance
    private let admissionCapacity: DynamicsCapacity

    @inline(never)
    init(restitution: Double, source: ConstrainedImpactProbeModel? = nil) throws {
        let original: ConstrainedImpactProbeModel
        if let source { original = source } else { original = try ConstrainedImpactProbeModel() }
        let construction = try Self.constructInput(original, restitution: restitution)
        self.source = original
        input = construction.input
        collisionConstructionWork = construction.collisionWork
        pairingConstructionWork = construction.contactWork
        policy = try Self.makePolicy()
        budget = try NumericalBudget(scalarStorage: 100_000, arithmeticOperations: 10_000_000, iterations: 10_000)
        contactBudget = try ContactBudget(operations: 100_000, scalarStorage: 10_000, records: 10)
        velocityTolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        admissionCapacity = try DynamicsCapacity(maximumBodies: 4, maximumVelocities: 3,
            maximumBodyWrenches: 0, maximumGeneralizedContributions: 0)
    }

    func makeWork() -> NumericalWork { NumericalWork(budget: budget) }
    func makeContactWork() -> ContactWork { ContactWork(budget: contactBudget) }

    func makeLoadWork(cancellation: HybridCancellation) throws(LoadError) -> LoadWork {
        LoadWork(budget: try LoadBudget(maximumWork: 100_000, maximumScalars: 10_000,
            isCancelled: { cancellation.isCancelled }))
    }

    func makeAdmission(cancellation: HybridCancellation) -> DynamicsAdmission {
        DynamicsAdmission(capacity: admissionCapacity, angularVelocityTolerance: velocityTolerance,
            linearVelocityTolerance: velocityTolerance, isCancelled: { cancellation.isCancelled })
    }

    @inline(never)
    func prepare(admission: DynamicsAdmission, loadWork: inout LoadWork, work: inout NumericalWork,
                 cancellation: HybridCancellation) throws(ConstrainedImpactError) -> PreparedConstrainedImpact {
        let preparer: any ConstrainedImpactPreparing = ReferenceConstrainedImpactPreparer()
        return try preparer.prepare(input: input, constraints: source.constraints, policy: policy,
            admission: admission, loadWork: &loadWork, work: &work, cancellation: cancellation)
    }

    @inline(never)
    func solve(_ prepared: PreparedConstrainedImpact, work: inout NumericalWork, contactWork: inout ContactWork,
               cancellation: HybridCancellation) throws(ConstrainedImpactError) -> ConstrainedNormalImpulseResult {
        let solver: any ConstrainedNormalImpulseSolving = ReferenceConstrainedNormalImpulseSolver()
        return try solver.solve(prepared, work: &work, contactWork: &contactWork, cancellation: cancellation)
    }

    private final class InputConstruction: Sendable {
        let input: HardImpactInput
        let collisionWork: CollisionWork
        let contactWork: ContactWork
        init(input: HardImpactInput, collisionWork: CollisionWork, contactWork: ContactWork) {
            self.input = input; self.collisionWork = collisionWork; self.contactWork = contactWork
        }
    }

    @inline(never)
    private static func constructInput(_ source: ConstrainedImpactProbeModel, restitution: Double) throws -> InputConstruction {
        var collision = CollisionWork(budget: try CollisionBudget(scalarStorage: 1000, operations: 100_000, iterations: 1000, records: 10))
        var contact = ContactWork(budget: try ContactBudget(operations: 100_000, scalarStorage: 10_000, records: 10))
        let input = try source.makeInput(restitution: restitution, collisionWork: &collision, contactWork: &contact)
        return InputConstruction(input: input, collisionWork: collision, contactWork: contact)
    }

    @inline(never)
    private static func makePolicy() throws -> ConstrainedImpactPolicy {
        let tolerance = try LinearTolerance<Double>(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-12)
        let lu = LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU)
        let nonlinear = try NonlinearPolicy<Double>(strategy: .newton, capability: lu, tolerance: tolerance,
            referenceScale: 1, minimumDirectionNorm: 0, derivativeProbeDistance: 1e-6,
            derivativeAbsoluteTolerance: 1e-5, derivativeRelativeTolerance: 1e-5, maximumFactorEntries: 100,
            estimateCondition: false, budget: NumericalBudget(scalarStorage: 10_000, arithmeticOperations: 100_000, iterations: 1000))
        return try ConstrainedImpactPolicy(impact: HybridPolicy(maximumContacts: 2, maximumColliders: 4,
            maximumBodies: 4, maximumVelocities: 3, maximumIdentifierBytes: 256, lengthTolerance: 1e-9,
            normalTolerance: 1e-10, speedTolerance: 1e-9, independenceTolerance: 1e-10, impulseScales: [1, 1, 1],
            momentumAbsolute: 1e-9, momentumRelative: 1e-10, energyAbsolute: 1e-9, energyRelative: 1e-10),
            constraints: ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 3, maximumRows: 3,
                expectedLayoutRevision: 1), diagonalMetric: [1, 1, 1], energyScale: 1, rankPolicy: .allowRedundancy,
                rankRelativeTolerance: 1e-10, originalResidualTolerance: 1e-9, maximumCorrection: 10,
                nonlinear: nonlinear, linearCapability: lu, linearTolerance: tolerance),
            dynamics: DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
                linearTolerance: tolerance, coordinateScales: [1, 1, 1], energyScale: 1, timeScale: 2),
            maximumFactorEntries: 100, minimumEffectiveInverseMass: 1e-12)
    }
}
