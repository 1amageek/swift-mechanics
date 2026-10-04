import SwiftMechanics

struct DerivativeProbeContext {
    let input: MechanicalDerivativeInput
    let direction: MechanicalDirection
    let jointPolicy: JointEvaluationPolicy
    let admission: DynamicsAdmission
    let policy: DerivativePolicy
    let solve: DynamicsSolvePolicy
    init() throws {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let root = try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .identity, policy: inertiaPolicy)
        let child = try MassProperties3D(mass: 2, centerOfMass: .unitX, inertiaAtCenter: Matrix3(2,0,0,0,3,0,0,0,4), policy: inertiaPolicy)
        var bodies: [KinematicBody] = [], inertias: [RigidBodyInertia] = [], directions: [BodyInertiaDirection] = []
        for (name, properties) in [("root", root), ("pendulum", child)] {
            let body = try EntityID(kind: .body, key: name), frame = try EntityID(kind: .frame, key: name + "-frame")
            bodies.append(KinematicBody(body: try BodyRecord3D(id: body, frame: frame, mode: .dynamic, bodyToWorld: .identity,
                representations: BodyRepresentations(), inertia: InertialRepresentation3D(properties: properties, provenance: SourceProvenance(source: "derivative-probe", revision: 1), quality: .exact))))
            inertias.append(try RigidBodyInertia(body: body, frame: frame, properties: properties))
            directions.append(BodyInertiaDirection(body: body, frame: frame))
        }
        let world = try EntityID(kind: .frame, key: "derivative-world")
        let joint = try JointRecord(id: EntityID(kind: .joint, key: "hinge"), parentBody: bodies[0].id, childBody: bodies[1].id,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "parent-anchor"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "child-anchor"), placement: .fixed(.identity)), manifold: JointManifold(.revolute(axis: .unitZ)))
        let tree = try KinematicTree(bodies: bodies, joints: [joint], root: bodies[0].id, rootBase: .fixed, worldFrame: world, revision: 1,
            capacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12))
        input = MechanicalDerivativeInput(tree: tree, state: try KinematicState(revision: 1, time: 0, q: [0.4], v: [0.7], acceleration: [37]),
            inertias: inertias, gravity: try AffineGravity(frame: world, accelerationAtOrigin: Vector3(0,-10,0)), drive: [2])
        direction = MechanicalDirection(tree: TreeDirection(revision: 1, configuration: [1], velocity: [0], acceleration: [0], screwPitch: [0]), inertias: directions, drive: [0])
        jointPolicy = try JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1)
        admission = DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 2, maximumVelocities: 1, maximumBodyWrenches: 0, maximumGeneralizedContributions: 0),
            angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance)
        policy = try DerivativePolicy(maximumBodies: 2, maximumVelocities: 1, maximumJacobianColumns: 1, tolerance: tolerance,
            residualTolerance: tolerance, physicalNeighborhood: 1e-3, inertiaValidation: inertiaPolicy)
        solve = try DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            linearTolerance: LinearTolerance(absoluteResidual: 1e-9, relativeResidual: 1e-10, pivotThreshold: 1e-12), coordinateScales: [0.25], energyScale: 7, timeScale: 3)
    }
}
