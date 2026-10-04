import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class FluidProbeContext: Sendable {
    typealias Session = RuntimeSession<ReferenceRuntimeCheckpointHandler<FluidRuntimeContributors, ReferenceModelRevisionUpdater>>
    let model: CompiledMechanicalModel
    let initial: FluidState
    let policy: FluidPolicy
    let codec: FixedFluidContinuationCodec
    let operation: ReferenceFluidTrialOperator
    let session: Session
    let budget: NumericalBudget
    init() throws {
        let original = try MechanicalProbeModel(), source = original.descriptor
        guard let root = source.bodies.first(where: { $0.id == source.root }) else { throw FoundationVerificationError.analyticCheckFailed }
        let descriptor = try MechanicalDescriptor(identity: "fluid-probe-carrier", revision: 1, bodies: [root], joints: [], root: source.root,
            rootBase: .fixed, rootAuthority: .fixed, worldFrame: source.worldFrame,
            initialState: KinematicState(revision: 1, time: 0, q: [], v: [], acceleration: []), representationRequirements: [], features: [], extensions: [])
        model = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: original.policy)
        let channel = try FluidChannel(id: "parallel-plate-probe", revision: 1, model: model.stamp, frame: source.worldFrame,
            source: SourceProvenance(source: "fluid-public-probe", revision: 1), boundaryLaw: "held-wall-source", boundaryRevision: 1,
            height: 1, wallArea: 2, density: 2, viscosity: 1, accelerationX: 0, accelerationY: -9.81, cells: 4,
            limits: FluidLimits(maximumCells: 4, maximumMetadataBytes: 1024, maximumSpeed: 10, maximumPressure: 100, maximumSource: 100, maximumStep: 1))
        policy = try FluidPolicy(forceAbsolute: 1e-9, forceRelative: 1e-10, pressureGradientAbsolute: 1e-8,
            energyAbsolute: 1e-9, energyRelative: 1e-10, powerAbsolute: 1e-9, powerRelative: 1e-10,
            linearTolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-11, pivotThreshold: 1e-14), isCancelled: { false })
        budget = try NumericalBudget(scalarStorage: 100000, arithmeticOperations: 1000000, iterations: 100)
        let fields: any FluidFieldBuilding = ReferenceFluidFieldBuilder()
        let evolution: any FluidEvolving = ReferenceViscousChannelSolver(linear: ReferenceLinearSolver<Double>(), fields: fields)
        let boundary = try FluidBoundary(lowerSpeed: 0, upperSpeed: 1, pressureGradientX: 0, lowerGaugePressure: 0)
        var work = NumericalWork(budget: budget)
        let zero = try fields.makeState(channel: channel, boundary: boundary, time: 0, velocities: [0,0,0,0], policy: policy, work: &work)
        initial = try evolution.steady(state: zero, boundary: boundary, policy: policy, work: &work).state
        codec = try FixedFluidContinuationCodec(channel: channel, contributorID: "fluid-channel", maximumBytes: 2048, pressureGradientTolerance: 1e-8)
        operation = ReferenceFluidTrialOperator(codec: codec, evolution: evolution)
        var bytes = try FluidByteWork(maximumBytes: 8192, maximumVisitedBytes: 8192)
        let record = try codec.encode(initial, work: &bytes)
        let capacity = try RuntimeCapacity(maximumPhysicalScalars: 0, maximumContributors: 1, maximumContributorBytes: 2048,
            maximumMetadataBytes: 2048, maximumCheckpointBytes: 4096, maximumValidationWork: 8192, maximumValidationScratchBytes: 8192,
            maximumObservationLeases: 1, maximumBatchStates: 1, maximumTransactions: 10, maximumStepWorkUnits: 8, maximumWorkBetweenSafePoints: 1)
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "fluid-swift-6.4.0", backend: "reference-cpu", precision: "float64"),
            requiredContributors: [codec.schema], capacity: capacity, determinism: .sameBuildReplay, workload: "viscous-channel")
        let handler = ReferenceRuntimeCheckpointHandler(contributors: FluidRuntimeContributors(codec: codec), revisions: ReferenceModelRevisionUpdater())
        session = try Session(model: model, configuration: configuration, initialState: descriptor.initialState, contributors: [record], seed: 42, checkpoints: handler)
    }
}
