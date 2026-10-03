import MechanicsCore
import MechanicsModel
@testable import MechanicsJoints

struct JointFixtures {
    static func policy() throws -> JointEvaluationPolicy {
        try JointEvaluationPolicy(quaternionTolerance: NumericalTolerance(absolute: 1e-12, relative: 1e-12),
                                  chartRankRelative: 1e-9, characteristicLengthMeters: 1)
    }
    static func capacity() throws -> KinematicCapacity {
        try KinematicCapacity(maximumBodies: 64, maximumVelocities: 128, maximumJacobianScalars: 64 * 128 * 6)
    }
    static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: key) }
    static func body(_ key: String, planar: Bool = false, pose: RigidTransform = .identity) throws -> KinematicBody {
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: NumericalTolerance(absolute: 0, relative: 0), physicalityRelative: 0)
        let source = try SourceProvenance(source: key, revision: 1)
        let representations = try BodyRepresentations()
        if planar {
            let record = try BodyRecord2D(id: id(.body, key), frame: id(.frame, key + "-frame"), mode: .dynamic,
                bodyToWorld: PlanarPose(x: pose.translation.x, y: pose.translation.y, angle: pose.rotation.rotationVector().z),
                representations: representations,
                inertia: InertialRepresentation2D(properties: MassProperties2D(mass: 1, centerX: 0, centerY: 0, polarInertiaAtCenter: 1),
                                                    provenance: source, quality: .exact))
            return try KinematicBody(body: record)
        }
        let record = try BodyRecord3D(id: id(.body, key), frame: id(.frame, key + "-frame"), mode: .dynamic, bodyToWorld: pose,
            representations: representations,
            inertia: InertialRepresentation3D(properties: MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .identity, policy: inertiaPolicy),
                                                provenance: source, quality: .exact))
        return KinematicBody(body: record)
    }
    static func joint(_ key: String, parent: String, child: String, specification: JointSpecification,
                      parentPlacement: AnchorPlacement = .fixed(.identity), childPlacement: AnchorPlacement = .fixed(.identity)) throws -> JointRecord {
        try JointRecord(id: id(.joint, key), parentBody: id(.body, parent), childBody: id(.body, child),
            parentAnchor: JointAnchor(frame: id(.frame, key + "-parent-anchor"), placement: parentPlacement),
            childAnchor: JointAnchor(frame: id(.frame, key + "-child-anchor"), placement: childPlacement),
            manifold: JointManifold(specification))
    }
    static func tree(bodies: [KinematicBody], joints: [JointRecord], root: String = "root", base: BaseLayout = .fixed) throws -> KinematicTree {
        try KinematicTree(bodies: bodies, joints: joints, root: id(.body, root), rootBase: base,
                          worldFrame: id(.frame, "world"), revision: 5, capacity: capacity())
    }
    static func state(q: [Double], v: [Double], acceleration: [Double]? = nil, time: Double = 0,
                      anchors: [PrescribedAnchorState] = []) throws -> KinematicState {
        try KinematicState(revision: 5, time: time, q: q, v: v, acceleration: acceleration ?? [Double](repeating: 0, count: v.count),
                           prescribedAnchors: anchors)
    }
    static func displaced(_ tree: KinematicTree, state: KinematicState, step: Double) throws -> KinematicState {
        let evaluator = JointMotionEvaluator(), policy = try policy()
        let signedVelocity = state.v.map { $0 * (step < 0 ? -1 : 1) }
        let dt = abs(step)
        var q: [Double] = []
        if tree.rootBase != .fixed {
            let specification: JointSpecification = tree.rootBase == .spatialFloating ? .sixDOF
                : .planar(firstTranslationAxis: .unitX, secondTranslationAxis: .unitY)
            q.append(contentsOf: try evaluator.integrating(JointManifold(specification), q: state.q[0..<tree.rootBase.positionCount],
                v: signedVelocity[0..<tree.rootBase.velocityCount], timeStep: dt, policy: policy))
        }
        for (index, joint) in tree.joints.enumerated() {
            let layout = tree.layout.joints[index]
            q.append(contentsOf: try evaluator.integrating(joint.manifold, q: state.q[layout.positions.range],
                v: signedVelocity[layout.velocities.range], timeStep: dt, policy: policy))
        }
        return try KinematicState(revision: state.revision, time: state.time + step, q: q, v: state.v,
                                  acceleration: state.acceleration, prescribedAnchors: state.prescribedAnchors)
    }
}
