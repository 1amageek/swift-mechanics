import SwiftMechanics
import Testing

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct RuntimeFixtures {
    typealias Handler = ReferenceRuntimeCheckpointHandler<CounterRuntimeContributors, ReferenceModelRevisionUpdater>
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
    static func capacity(physical: Int = 100, transactions: UInt64 = 1000, observers: Int = 2, batch: Int = 8, bytes: Int = 4096) throws -> RuntimeCapacity {
        try RuntimeCapacity(maximumPhysicalScalars: physical, maximumContributors: 8, maximumContributorBytes: 128,
            maximumMetadataBytes: 1000, maximumCheckpointBytes: bytes, maximumValidationWork: 64, maximumValidationScratchBytes: 64,
            maximumObservationLeases: observers, maximumBatchStates: batch, maximumTransactions: transactions,
            maximumStepWorkUnits: 100, maximumWorkBetweenSafePoints: 4)
    }
    static func configuration(capacity: RuntimeCapacity? = nil, build: String = "fixture-v1", backend: String = "reference-cpu",
                              tier: RuntimeDeterminismTier = .sameBuildReplay) throws -> RuntimeConfiguration {
        try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: build, backend: backend, precision: "float64"),
            requiredContributors: CounterRuntimeContributors().schemas, capacity: capacity ?? self.capacity(), determinism: tier, workload: "hinge-counter-rng")
    }
    static func handler() throws -> Handler { try Handler(contributors: CounterRuntimeContributors(), revisions: ReferenceModelRevisionUpdater()) }
    static func session(model: CompiledMechanicalModel? = nil, configuration: RuntimeConfiguration? = nil, seed: UInt64 = 42,
                        onRelease: (@Sendable () -> Void)? = nil) throws -> Session {
        let compiled = try model ?? self.model(), config = try configuration ?? self.configuration()
        return try Session(model: compiled, configuration: config, initialState: compiled.descriptor.initialState,
            contributors: [CounterRuntimeContributors.record(0)], seed: seed, checkpoints: handler(), onRelease: onRelease)
    }
    static func advance(_ session: any RuntimeSessionOperating) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try control.beginWorkBlock(units: 1)
            let previous = try CounterRuntimeContributors.count(trial.contributor("integrator-counter"))
            guard previous < UInt64.max else { throw RuntimeFailure(.capacityExceeded, message: "Fixture counter overflow.") }
            let random = try trial.nextRandom()
            try trial.setPosition(trial.position(at: 0) + Double((random & 15) + 1) / 16, at: 0)
            try trial.setVelocity(Double(previous + 1), at: 0)
            try trial.setTime(trial.timeSeconds + 0.25)
            try trial.replaceContributor(CounterRuntimeContributors.record(previous + 1))
            return .accept
        }
    }
    static func failure(_ code: RuntimeFailureCode, operation: () throws(RuntimeFailure) -> Void) {
        do throws(RuntimeFailure) { try operation(); Issue.record("Expected runtime failure was not returned.") }
        catch { #expect(error.code == code) }
    }
    static func repairedChecksum(_ source: [UInt8]) -> [UInt8] {
        var bytes = source, checksum: UInt64 = 0xcbf29ce484222325
        for byte in bytes[28...] { checksum = (checksum ^ UInt64(byte)) &* 0x100000001b3 }
        for i in 0..<8 { bytes[20+i] = UInt8(truncatingIfNeeded: checksum >> (8*i)) }
        return bytes
    }
}
