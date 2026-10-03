import MechanicsCore
import MechanicsModel
import MechanicsJoints

extension FoundationVerification {
    static func verifyKinematics() throws {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let policy = try JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-9, characteristicLengthMeters: 1)
        let evaluator: any JointMotionEvaluating = JointMotionEvaluator()
        let spherical = try JointManifold(.spherical)
        let sphere = try evaluator.evaluate(spherical, q: [1,0,0,0][...], v: [0,0,3][...], acceleration: [0,0,0][...], policy: policy)
        guard sphere.coordinateRate.count == 4, sphere.subspace.columns.count == 3,
              abs(sphere.coordinateRate[3] - 1.5) < 1e-12 else { throw FoundationVerificationError.analyticCheckFailed }
        let root = try verificationBody("probe-root"), child = try verificationBody("probe-child")
        let hinge = try JointRecord(id: EntityID(kind: .joint, key: "probe-hinge"), parentBody: root.id, childBody: child.id,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "probe-parent-anchor"),
                placement: .fixed(RigidTransform(rotation: .identity, translation: Vector3(2,0,0)))),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "probe-child-anchor"), placement: .fixed(.identity)),
            manifold: JointManifold(.revolute(axis: .unitZ)))
        let tree = try KinematicTree(bodies: [root, child], joints: [hinge], root: root.id, rootBase: .fixed,
            worldFrame: EntityID(kind: .frame, key: "probe-world"), revision: 1,
            capacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12))
        let state = try KinematicState(revision: 1, time: 0, q: [.pi / 2], v: [3], acceleration: [0])
        let treeEvaluator: any TreeKinematicsComputing = TreeKinematicsEvaluator()
        let snapshot = try treeEvaluator.evaluate(tree, state: state, policy: policy)
        let calculator: any KinematicJacobianComputing = KinematicJacobianCalculator()
        let point = try calculator.pointMotion(body: child.id, bodyLocalPoint: .unitX, snapshot: snapshot)
        guard try point.position.subtracting(Vector3(2,1,0)).magnitude() < 1e-12,
              try point.velocity.subtracting(Vector3(-3,0,0)).magnitude() < 1e-12,
              try point.acceleration.subtracting(Vector3(0,-9,0)).magnitude() < 1e-12 else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let jacobian = try calculator.point(body: child.id, bodyLocalPoint: .unitX, snapshot: snapshot)
        let force = try Vector3(2,3,0)
        let generalizedForce = try jacobian.transposed(against: force)
        guard abs(generalizedForce[0] + 2) < 1e-12,
              abs(try force.dot(point.velocity) - generalizedForce[0] * state.v[0]) < 1e-12 else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let stale = try KinematicState(revision: 2, time: 0, q: state.q, v: state.v, acceleration: state.acceleration)
        var rejected = false
        do { _ = try treeEvaluator.evaluate(tree, state: stale, policy: policy) }
        catch { rejected = true }
        guard rejected else { throw FoundationVerificationError.analyticCheckFailed }
    }

    private static func verificationBody(_ key: String) throws -> KinematicBody {
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: NumericalTolerance(absolute: 0, relative: 0), physicalityRelative: 0)
        let mass = try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .identity, policy: inertiaPolicy)
        let body = try BodyRecord3D(id: EntityID(kind: .body, key: key), frame: EntityID(kind: .frame, key: key + "-frame"),
            mode: .dynamic, bodyToWorld: .identity, representations: BodyRepresentations(),
            inertia: InertialRepresentation3D(properties: mass, provenance: SourceProvenance(source: key, revision: 1), quality: .exact))
        return KinematicBody(body: body)
    }
}
