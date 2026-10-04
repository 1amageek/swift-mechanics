import SwiftMechanics

/// Original compiled mechanics and force observations for public identification.
final class ParameterIdentificationProbeContext: Sendable {
    let fixture: ParameterIdentificationProbeModel
    let source: PrismaticIdentificationSource
    let problem: PhysicalIdentificationProblem
    let unidentifiableProblem: PhysicalIdentificationProblem
    let policy: IdentificationPolicy
    let budget: NumericalBudget
    let loadBudget: LoadBudget

    @inline(never)
    convenience init() throws {
        try self.init(fixture: ParameterIdentificationProbeModel())
    }

    @inline(never)
    init(fixture: ParameterIdentificationProbeModel) throws {
        let source = try Self.source(fixture)
        let metadata = try Self.metadata(source)
        self.fixture = fixture
        self.source = source
        problem = try Self.problem(fixture, source: source, metadata: metadata, correlated: false)
        unidentifiableProblem = try Self.problem(fixture, source: source, metadata: metadata, correlated: true)
        policy = try Self.policy(fixture)
        budget = try NumericalBudget(scalarStorage: 1_000_000, arithmeticOperations: 10_000_000, iterations: 1000)
        loadBudget = try LoadBudget(maximumWork: 10_000, maximumScalars: 0)
    }

    func work() -> NumericalWork { NumericalWork(budget: budget) }
    func loadWork() -> LoadWork { LoadWork(budget: loadBudget) }
    func supplierWork() throws(DerivativeError) -> DerivativeSupplierWork {
        try DerivativeSupplierWork(maximumCalls: 10_000)
    }
    func workspace() -> IdentificationWorkspace { IdentificationWorkspace() }

    @inline(never)
    func estimate(_ selected: PhysicalIdentificationProblem? = nil,
        using service: any PhysicalParameterIdentifying = PhysicalMassDamperIdentifier(),
        workspace: inout IdentificationWorkspace, loadWork: inout LoadWork,
        supplierWork: inout DerivativeSupplierWork, work: inout NumericalWork)
        throws(ParameterIdentificationFailure) -> PhysicalParameterEstimate {
        try service.estimate(selected ?? problem, policy: policy, workspace: &workspace,
            loadWork: &loadWork, supplierWork: &supplierWork, work: &work)
    }

    @inline(never)
    private static func source(_ fixture: ParameterIdentificationProbeModel) throws -> PrismaticIdentificationSource {
        var inertias: [RigidBodyInertia] = []
        for body in fixture.model.tree.bodies {
            guard let record = fixture.model.descriptor.bodies.first(where: { $0.id == body.id }),
                  case .spatial(let spatial) = record, let inertia = spatial.inertia else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            inertias.append(try RigidBodyInertia(body: spatial.id, frame: spatial.frame, properties: inertia.properties))
        }
        return PrismaticIdentificationSource(tree: fixture.model.tree, referenceInertias: inertias,
            body: ModelReference(id: fixture.body, revision: fixture.model.stamp.revision),
            massParameterID: 11, dampingParameterID: 12, dashpotRestCoordinate: 0,
            maximumDisplacement: 10, maximumRate: 100)
    }

    @inline(never)
    private static func metadata(_ source: PrismaticIdentificationSource) throws -> OptimizationMetadata {
        try OptimizationMetadata(identity: "parameter-identification-public-observations",
            provenance: SourceProvenance(source: "parameter-identification-original-force-observations",
                revision: source.tree.revision),
            variableIDs: [source.massParameterID, source.dampingParameterID],
            variableReferences: [SIReferenceQuantity(magnitude: 1, dimension: .mass),
                SIReferenceQuantity(magnitude: 1, dimension: PhysicalDimension(mass: 1, time: -1))],
            objectiveReference: SIReferenceQuantity(magnitude: 1, dimension: .dimensionless))
    }

    @inline(never)
    private static func problem(_ fixture: ParameterIdentificationProbeModel, source: PrismaticIdentificationSource,
        metadata: OptimizationMetadata, correlated: Bool) throws -> PhysicalIdentificationProblem {
        let first = try Self.observation(fixture, time: 0, position: 0, velocity: 1,
            acceleration: correlated ? 2 : 1, force: correlated ? 4.5 : 2.5)
        let second = try Self.observation(fixture, time: 1, position: 0.3, velocity: -2,
            acceleration: correlated ? -4 : 1, force: correlated ? -9 : 1)
        return PhysicalIdentificationProblem(source: source, observations: [first, second], metadata: metadata,
            lowerBounds: [0.2, 0], upperBounds: [4, 4])
    }

    @inline(never)
    private static func observation(_ fixture: ParameterIdentificationProbeModel, time: Double,
        position: Double, velocity: Double, acceleration: Double, force: Double) throws -> ForceObservation {
        var q = [Double](repeating: 0, count: fixture.model.tree.layout.positionCount)
        var v = [Double](repeating: 0, count: fixture.model.tree.layout.velocityCount)
        var a = [Double](repeating: 0, count: fixture.model.tree.layout.velocityCount)
        q[fixture.positionIndex] = position
        v[fixture.velocityIndex] = velocity
        a[fixture.velocityIndex] = acceleration
        let compiled = try fixture.model.makeState(KinematicState(revision: fixture.model.stamp.revision,
            time: time, q: q, v: v, acceleration: a))
        return ForceObservation(state: compiled.state, appliedForceNewtons: force, forceStandardDeviationNewtons: 1)
    }

    @inline(never)
    private static func policy(_ fixture: ParameterIdentificationProbeModel) throws -> IdentificationPolicy {
        let tolerance = try NumericalTolerance(absolute: 1e-8, relative: 1e-10)
        let velocityTolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let inertia = fixture.model.policy.inertiaPolicy
        let capability = LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky)
        let linear = try LinearTolerance<Double>(absoluteResidual: 1e-9, relativeResidual: 1e-10, pivotThreshold: 1e-12)
        return try IdentificationPolicy(maximumObservations: 2, maximumMetadataBytes: 100_000,
            maximumModelValidationAttempts: 100, rankThreshold: 1e-10,
            physicalAgreement: tolerance, normalizedAgreement: tolerance, informationAgreement: tolerance,
            joint: fixture.model.policy.jointPolicy,
            dynamics: DynamicsAdmission(capacity: DynamicsCapacity(maximumBodies: 2, maximumVelocities: 1,
                maximumBodyWrenches: 0, maximumGeneralizedContributions: 1),
                angularVelocityTolerance: velocityTolerance, linearVelocityTolerance: velocityTolerance),
            derivative: DerivativePolicy(maximumBodies: 2, maximumVelocities: 1, maximumJacobianColumns: 2,
                tolerance: tolerance, residualTolerance: tolerance, physicalNeighborhood: 1e-3, inertiaValidation: inertia),
            inertiaValidation: inertia,
            optimization: OptimizationPolicy(maximumVariables: 2, maximumRows: 4, maximumNonzeros: 8,
                maximumFactorEntries: 16, maximumCandidateBases: 100, rankThreshold: 1e-10,
                certificateAbsolute: 1e-9, certificateRelative: 1e-10,
                luCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
                curvatureCapability: capability, linearTolerance: linear),
            informationCapability: capability, informationTolerance: linear)
    }
}
