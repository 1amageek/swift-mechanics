import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class MovingAnchorProbeContext {
    typealias Session = RuntimeSession<ReferenceRuntimeCheckpointHandler<ProbeRuntimeContributors, ReferenceModelRevisionUpdater>>
    let model: CompiledMechanicalModel
    let configuration: RuntimeConfiguration
    let handler: ReferenceRuntimeCheckpointHandler<ProbeRuntimeContributors, ReferenceModelRevisionUpdater>
    let child: EntityID

    @inline(never)
    init() throws {
        let baseline = try MechanicalProbeModel()
        let old = baseline.descriptor.joints[0].record
        let joint = try JointRecord(id: old.id, parentBody: old.parentBody, childBody: old.childBody,
            parentAnchor: JointAnchor(frame: Self.frame(), placement: .prescribed), childAnchor: old.childAnchor,
            manifold: old.manifold)
        child = old.childBody
        let initial = try KinematicState(revision: 1, time: 0, q: [0], v: [0], acceleration: [0],
            prescribedAnchors: [Self.sample(time: 0)])
        var bodies: [BodyRecord3D] = []
        for record in baseline.descriptor.bodies {
            guard case .spatial(let body) = record else { throw FoundationVerificationError.analyticCheckFailed }
            bodies.append(body)
        }
        let tree = try KinematicTree(bodies: bodies.map { KinematicBody(body: $0) }, joints: [joint],
            root: baseline.descriptor.root, rootBase: .fixed, worldFrame: baseline.descriptor.worldFrame,
            revision: 1, capacity: baseline.policy.kinematicCapacity)
        let evaluated = try TreeKinematicsEvaluator().evaluate(tree, state: initial, policy: baseline.policy.jointPolicy)
        var adjusted: [MechanicalBody] = []
        for body in bodies {
            let replacement = try BodyRecord3D(id: body.id, frame: body.frame, mode: body.mode,
                bodyToWorld: evaluated.body(body.id).motion.pose, representations: body.representations, inertia: body.inertia)
            adjusted.append(.spatial(replacement))
        }
        let descriptor = try MechanicalDescriptor(identity: "moving-anchor-public-probe", revision: 1,
            bodies: adjusted, joints: [MechanicalJoint(record: joint, authority: .dynamicState)],
            root: baseline.descriptor.root, rootBase: .fixed, rootAuthority: .fixed, worldFrame: tree.worldFrame,
            initialState: initial, representationRequirements: [], features: [], extensions: [])
        model = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: baseline.policy)
        let provider = try ProbeRuntimeContributors()
        let capacity = try RuntimeCapacity(maximumPhysicalScalars: 23, maximumContributors: 1, maximumContributorBytes: 8,
            maximumMetadataBytes: 1000, maximumCheckpointBytes: 4096, maximumValidationWork: 8,
            maximumValidationScratchBytes: 0, maximumObservationLeases: 1, maximumBatchStates: 2,
            maximumTransactions: 100, maximumStepWorkUnits: 8, maximumWorkBetweenSafePoints: 2)
        configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "anchor-swift-6.4.0",
            backend: "reference-cpu", precision: "float64"), requiredContributors: provider.schemas,
            capacity: capacity, determinism: .sameBuildReplay, workload: "complete-anchor-replay")
        handler = ReferenceRuntimeCheckpointHandler(contributors: provider, revisions: ReferenceModelRevisionUpdater())
    }

    @inline(never)
    func session() throws -> Session {
        try Session(model: model, configuration: configuration, initialState: model.descriptor.initialState,
            contributors: [ProbeRuntimeContributors.record(0)], seed: 42, checkpoints: handler)
    }

    static func frame() throws -> EntityID { try EntityID(kind: .frame, key: "public-moving-parent") }

    static func sample(time: Double) throws(RuntimeFailure) -> PrescribedAnchorState {
        do {
            let positive = try UnitQuaternion(axis: .unitZ, angle: 0.3 + 0.4 * time + 0.1 * time * time)
            let rotation = try UnitQuaternion(unitW: -positive.w, x: -positive.x, y: -positive.y, z: -positive.z)
            let pose = RigidTransform(rotation: rotation, translation: try Vector3(0.2 + 0.6 * time + 0.15 * time * time, -0.0, 0))
            return try PrescribedAnchorState(frame: frame(), time: time, motion: FrameMotion(pose: pose,
                velocity: SpatialMotion(angular: Vector3(-0.0, 0, 0.4 + 0.2 * time), linear: Vector3(0.6 + 0.3 * time, -0.0, 0)),
                acceleration: SpatialMotion(angular: Vector3(0, -0.0, 0.2), linear: Vector3(0.3, 0, -0.0))))
        } catch { throw RuntimeFailure(.invalidState, message: "Public moving sample construction failed.") }
    }
}
