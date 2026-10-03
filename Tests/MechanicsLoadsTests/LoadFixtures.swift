import MechanicsCore
import MechanicsModel
import MechanicsJoints
import MechanicsLoads
struct LoadFixtures {
    static func work(_ units: Int = 10000, scalars: Int = 10000) throws -> LoadWork {
        LoadWork(budget: try LoadBudget(maximumWork: units, maximumScalars: scalars))
    }
    static func body() throws -> EntityID { try EntityID(kind: .body, key: "body") }
    static func frame() throws -> EntityID { try EntityID(kind: .frame, key: "world") }
    static func snapshot(prescribed: Bool = false) throws -> KinematicSnapshot {
        func body(_ key: String) throws -> KinematicBody {
            KinematicBody(body: try BodyRecord3D(id: EntityID(kind: .body, key: key),
                frame: EntityID(kind: .frame, key: key + "-frame"), mode: .static, bodyToWorld: .identity,
                representations: BodyRepresentations(), inertia: nil))
        }
        let root = try body("root"), child = try body("body")
        let anchor = try EntityID(kind: .frame, key: "parent-anchor")
        let joint = try JointRecord(id: EntityID(kind: .joint, key: "hinge"), parentBody: root.id, childBody: child.id,
            parentAnchor: JointAnchor(frame: anchor, placement: prescribed ? .prescribed : .fixed(.identity)),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "child-anchor"), placement: .fixed(.identity)),
            manifold: JointManifold(.revolute(axis: .unitZ)))
        let tree = try KinematicTree(bodies: [root, child], joints: [joint], root: root.id, rootBase: .fixed,
            worldFrame: frame(), revision: 1, capacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12))
        let anchors = prescribed ? [try PrescribedAnchorState(frame: anchor, time: 0,
            motion: FrameMotion(pose: .identity, velocity: SpatialMotion(angular: .zero, linear: Vector3(0, 3, 0)), acceleration: FrameMotion.zeroMotion))] : []
        return try TreeKinematicsEvaluator().evaluate(tree, state: KinematicState(revision: 1, time: 0,
            q: [0], v: [2], acceleration: [0], prescribedAnchors: anchors),
            policy: JointEvaluationPolicy(quaternionTolerance: NumericalTolerance(absolute: 1e-12, relative: 1e-12),
                chartRankRelative: 1e-9, characteristicLengthMeters: 1))
    }
}
