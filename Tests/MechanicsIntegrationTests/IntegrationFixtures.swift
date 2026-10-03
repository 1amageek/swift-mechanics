import Testing
import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints
import MechanicsCompiler
import MechanicsRuntime
import MechanicsIntegration

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct IntegrationFixtures {
    typealias Handler = ReferenceRuntimeCheckpointHandler<IntegrationTestContributors,ReferenceModelRevisionUpdater>
    typealias Session = RuntimeSession<Handler>
    static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: key) }
    static func model(revision: UInt64 = 1, mass: Double = 1, floating: Bool = false) throws -> CompiledMechanicalModel {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let source = try SourceProvenance(source: "runtime-fixture", revision: revision)
        let inertia = try InertialRepresentation3D(properties: MassProperties3D(mass: mass, centerOfMass: .zero, inertiaAtCenter: .identity, policy: inertiaPolicy), provenance: source, quality: .exact)
        let root = try BodyRecord3D(id: id(.body, "root"), frame: id(.frame, "root-frame"), mode: floating ? .dynamic : .static,
            bodyToWorld: .identity, representations: BodyRepresentations(), inertia: inertia)
        let child = try BodyRecord3D(id: id(.body, "child"), frame: id(.frame, "child-frame"), mode: .dynamic,
            bodyToWorld: .identity, representations: BodyRepresentations(), inertia: inertia)
        let joint = try JointRecord(id: id(.joint, "hinge"), parentBody: root.id, childBody: child.id,
            parentAnchor: JointAnchor(frame: id(.frame, "parent-anchor"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: id(.frame, "child-anchor"), placement: .fixed(.identity)), manifold: JointManifold(.revolute(axis: .unitZ)))
        let state = try KinematicState(revision: revision, time: 0, q: floating ? [0,0,0,-1,0,0,0] : [0], v: floating ? [0,0,0,0,0,0] : [0], acceleration: floating ? [0,0,0,0,0,0] : [0])
        let descriptor = try MechanicalDescriptor(identity: "runtime-model", revision: revision, bodies: floating ? [.spatial(root)] : [.spatial(root),.spatial(child)],
            joints: floating ? [] : [MechanicalJoint(record: joint, authority: .dynamicState)], root: root.id,
            rootBase: floating ? .spatialFloating : .fixed, rootAuthority: floating ? .dynamicState : .fixed,
            worldFrame: id(.frame, "world"), initialState: state, representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 8, maximumVelocities: 32, maximumJacobianScalars: 1536),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-9, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 100, maximumIdentifierBytes: 10000, maximumSparsityEntries: 1000, maximumDependencyEntries: 1000,
            maximumExtensionRecords: 8, maximumDiagnostics: 8, extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10), target: .nativeCPU)
        return try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
    }

    static func policy(method: ExplicitIntegrationMethod = .classicalRK4, step: Double = 0.1, tolerance: Double = 1e-6,
                       minimum: Double = 1e-8, maximum: Double = 1, attempts: Int = 100000, steps: Int = 100000,
                       outer: Int = 100000000, supplier: Int = 1000000) throws -> ExplicitIntegrationPolicy {
        try ExplicitIntegrationPolicy(method: method,initialStep: step,minimumStep: minimum,maximumStep: maximum,
            safety: 0.8,minimumFactor: 0.1,maximumFactor: 2,
            scales: [ODEErrorScale(dimension: .angle,absoluteSI: tolerance,relative: 0),
                     ODEErrorScale(dimension: PhysicalDimension(time: -1,angle: 1),absoluteSI: tolerance,relative: 0)],
            maximumContinuationBytes: 2048,
            budget: IntegrationBudget(maximumCoordinates: 2,maximumAttempts: attempts,maximumAcceptedSteps: steps,maximumOuterArithmetic: outer,
                supplier: NumericalBudget(scalarStorage: 100,arithmeticOperations: supplier,iterations: 100000)))
    }
    static func session(model: CompiledMechanicalModel, equation: ManufacturedHingeEquation, policy: ExplicitIntegrationPolicy,
                        q: Double = 1, v: Double = 0, work: Int = 1000, records: [RuntimeContributorState]? = nil) throws -> (Session,IntegrationContinuationProvider) {
        let continuation = try IntegrationContinuationProvider(descriptor: equation.descriptor,policy: policy)
        let state = try KinematicState(revision: model.stamp.revision,time: 0,q: [q],v: [v],acceleration: [equation.accelerationCoefficient*q])
        let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "integration-fixture-v1",backend: "reference-cpu",precision: "float64"),
            requiredContributors: IntegrationTestContributors(integration: continuation).schemas,
            capacity: RuntimeCapacity(maximumPhysicalScalars: 3,maximumContributors: 4,maximumContributorBytes: 4096,maximumMetadataBytes: 4096,
                maximumCheckpointBytes: 8192,maximumValidationWork: 4096,maximumValidationScratchBytes: 1000,maximumObservationLeases: 2,
                maximumBatchStates: 4,maximumTransactions: 100000,maximumStepWorkUnits: work,maximumWorkBetweenSafePoints: 4),
            determinism: .sameBuildReplay,workload: "manufactured-ode")
        let handler = try Handler(contributors: IntegrationTestContributors(integration: continuation),revisions: ReferenceModelRevisionUpdater())
        return (try Session(model: model,configuration: configuration,initialState: state,
            contributors: records ?? [continuation.initialRecord(physical: state,equations: equation),IntegrationTestContributors.counter()],seed: 7,checkpoints: handler),continuation)
    }
    static func failure(_ code: RuntimeFailureCode, _ body: () throws(IntegrationFailure) -> Void) -> IntegrationFailure? {
        do throws(IntegrationFailure) { try body(); Issue.record("Expected contextual integration failure."); return nil }
        catch { #expect(error.cause.code == code); return error }
    }
}
