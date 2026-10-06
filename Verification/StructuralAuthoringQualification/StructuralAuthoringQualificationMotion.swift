import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public enum StructuralAuthoringQualificationMotion {
    public typealias Session = RuntimeSession<ReferenceRuntimeCheckpointHandler<IntegrationContinuationProvider, ReferenceModelRevisionUpdater>>

    public static func evolve(_ equation: AffineMechanismEquation) throws -> KinematicState {
        let scales = try [ODEErrorScale(dimension: .angle, absoluteSI: 1e-5, relative: 0),
            ODEErrorScale(dimension: .angle, absoluteSI: 1e-5, relative: 0),
            ODEErrorScale(dimension: PhysicalDimension(time: -1, angle: 1), absoluteSI: 1e-5, relative: 0),
            ODEErrorScale(dimension: PhysicalDimension(time: -1, angle: 1), absoluteSI: 1e-5, relative: 0)]
        let policy = try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: 0.1, minimumStep: 1e-8,
            maximumStep: 0.1, safety: 0.8, minimumFactor: 0.1, maximumFactor: 2, scales: scales,
            maximumContinuationBytes: 2048, budget: IntegrationBudget(maximumCoordinates: 4, maximumAttempts: 1000,
                maximumAcceptedSteps: 1000, maximumOuterArithmetic: 1_000_000,
                supplier: NumericalBudget(scalarStorage: 1_000_000, arithmeticOperations: 100_000_000, iterations: 100_000)))
        let continuation = try IntegrationContinuationProvider(descriptor: equation.descriptor, policy: policy)
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "structural-qualification-v1",
            backend: "reference-cpu", precision: "float64"), requiredContributors: continuation.schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 4, maximumContributorBytes: 4096,
                maximumMetadataBytes: 65_536, maximumCheckpointBytes: 131_072, maximumValidationWork: 131_072,
                maximumValidationScratchBytes: 131_072, maximumObservationLeases: 2, maximumBatchStates: 2,
                maximumTransactions: 1000, maximumStepWorkUnits: 100_000, maximumWorkBetweenSafePoints: 4),
            determinism: .sameBuildReplay, workload: "authored-real-gear")
        let handler = ReferenceRuntimeCheckpointHandler(contributors: continuation, revisions: ReferenceModelRevisionUpdater())
        let model = equation.model
        let session = try Session(model: model, configuration: configuration, initialState: model.descriptor.initialState,
            contributors: [continuation.initialRecord(physical: model.descriptor.initialState, equations: equation)],
            seed: 42, checkpoints: handler)
        defer { _ = session.shutdown() }
        return try ReferenceExplicitIntegrator().advance(session, model: model, equations: equation,
            continuation: continuation, to: 0.2).accepted.checkpoint.physical
    }

    public static func reaction(_ authored: StructuralMechanicalSystem) throws -> (RigidDynamicsSystem, ConstrainedMotion) {
        guard let network = authored.transmission else { throw StructuralAuthoringQualificationError.assertion("Actual gear network is absent") }
        var work = try StructuralAuthoringQualificationFixtures.numerical()
        var load = try StructuralAuthoringQualificationFixtures.loads()
        var inertias: [RigidBodyInertia] = []
        for body in authored.model.tree.bodies {
            guard let original = authored.model.descriptor.bodies.first(where: { $0.id == body.id }),
                  case .spatial(let record) = original, let source = record.inertia else {
                throw StructuralAuthoringQualificationError.assertion("Complete source inertia is absent")
            }
            inertias.append(try RigidBodyInertia(body: record.id, frame: record.frame, properties: source.properties))
        }
        let physical = authored.model.descriptor.initialState
        let input = try RigidDynamicsInput(snapshot: authored.model.initialSnapshot, velocity: physical.v,
            inertias: inertias, gravity: nil)
        let system = try RigidEquationKernel().assemble(input, admission: StructuralAuthoringQualificationFixtures.admission(),
            loadWork: &load, work: &work)
        let policy = try StructuralAuthoringQualificationFixtures.mechanismPolicy()
        let original = try QuadraticConstraintEvaluator().evaluate(network.equations, position: physical.q,
            velocity: physical.v, time: physical.time, policy: policy.constraints.evaluation, work: &work)
        let rows = VelocityConstraintSample(layout: authored.layout, holonomic: original)
        var dynamics = try StructuralAuthoringQualificationFixtures.numerical()
        var rank = try StructuralAuthoringQualificationFixtures.numerical()
        var linear = try StructuralAuthoringQualificationFixtures.numerical()
        let solver: any ConstrainedMechanismSolving = MassWeightedMechanismSolver()
        let motion = try solver.acceleration(system, sample: rows, drive: authored.drive, policy: policy,
            work: &work, dynamicsWork: &dynamics, rankWork: &rank, linearWork: &linear)
        return (system, motion)
    }
}
