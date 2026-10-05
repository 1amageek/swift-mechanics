import SwiftMechanics

public enum FrictionalImpulseQualificationFixtures {
    public static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: "friction-" + key) }
    public static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute: 1e-11, relative: 1e-11) }
    public static func joints() throws -> JointEvaluationPolicy {
        try JointEvaluationPolicy(quaternionTolerance: tolerance(), chartRankRelative: 1e-10, characteristicLengthMeters: 1)
    }
    public static func policy(mu: Double = 1, massScale: Double = 1, velocityScale: Double = 1, coordinates: Int = 6,
                              bodies: Int = 4, identifiers: Int = 256, bracket: Int = 80, bisection: Int = 80,
                              cancelled: @escaping @Sendable () -> Bool = { false }) throws -> FrictionalImpulsePolicy {
        let hybrid = try HybridPolicy(maximumContacts: 1, maximumColliders: 4, maximumBodies: bodies, maximumVelocities: 6,
            maximumIdentifierBytes: identifiers, lengthTolerance: 1e-8, normalTolerance: 1e-10, speedTolerance: 1e-8,
            independenceTolerance: 1e-10, impulseScales: [Double](repeating: 1, count: coordinates),
            momentumAbsolute: 1e-8, momentumRelative: 1e-10, energyAbsolute: 1e-8, energyRelative: 1e-10)
        let admission = try DynamicsAdmission(capacity: DynamicsCapacity(maximumBodies: 4, maximumVelocities: 6,
            maximumBodyWrenches: 0, maximumGeneralizedContributions: 0), angularVelocityTolerance: tolerance(), linearVelocityTolerance: tolerance())
        let linear = try LinearTolerance<Double>(absoluteResidual: 1e-11, relativeResidual: 1e-11, pivotThreshold: 1e-12)
        return try FrictionalImpulsePolicy(hybrid: hybrid, joints: joints(), admission: admission,
            mass: DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
                linearTolerance: linear, coordinateScales: [Double](repeating: 1, count: coordinates), energyScale: 1, timeScale: 1),
            tangentTolerance: linear, coefficient: mu, massScaleKg: massScale, velocityScale: velocityScale,
            impulseTolerance: tolerance(), maximumBracketIterations: bracket, maximumBisectionIterations: bisection, isCancelled: cancelled)
    }
    public static func numerical(storage: Int = 100_000, operations: Int = 5_000_000, iterations: Int = 10_000) throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: iterations))
    }
    public static func loads() throws -> LoadWork { LoadWork(budget: try LoadBudget(maximumWork: 100_000, maximumScalars: 4096)) }
    public static func contacts(operations: Int = 10_000) throws -> ContactWork {
        ContactWork(budget: try ContactBudget(operations: operations, scalarStorage: 1024, records: 32))
    }
    public static func law(e: Double, threshold: Double, compliant: Bool = false) throws -> ContactLawPair {
        func material(_ key: String) throws -> ContactMaterial {
            try ContactMaterial(reference: ModelReference(id: id(.material, key), revision: 7), youngModulus: 1e6, poissonsRatio: 0.2,
                linearStiffness: 2000, normalDamping: 0, huntCrossleyAlpha: 0, friction: .none,
                resistance: ContactResistanceParameters(rollingCoefficient: 0, spinningCoefficient: 0, angularRegularization: 0.1), cohesion: .none)
        }
        var work = try contacts()
        let pairing: any ContactMaterialPairing = SeriesContactPairing()
        return try pairing.combine(first: material("plane"), second: material("sphere"),
            selection: .linear(maximumPenetration: 1, maximumNormalSpeed: 100),
            lossPolicy: compliant ? .compliantDampingOnly : .separateImpact(restitution: e, thresholdSpeed: threshold),
            resistanceRadius: 1, override: nil, work: &work)
    }
    public static func input(vx: Double = 2, vy: Double = 0, vz: Double = -2, ix: Double = 1, iy: Double = 1,
                             ixy: Double = 0, iz: Double = 1, comX: Double = 0, e: Double = 0.5, threshold: Double = 0,
                             wallSpeed: Double? = nil, normalOnly: Bool = false, basisRotation: UnitQuaternion = .identity,
                             compliant: Bool = false) throws -> FrictionalImpulseInput {
        let provenance = try SourceProvenance(source: "independent-sphere-plane", revision: 7)
        let representations = try BodyRepresentations(collisionGeometry: GeometryRepresentation(kind: .collisionGeometry,
            assetKey: "actual-analytic", provenance: provenance, quality: .exact))
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance(), physicalityRelative: 0)
        let rootID = try id(.body, "ground"), ballID = try id(.body, "ball"), world = try id(.frame, "world")
        let rootFrame = try id(.frame, "ground-frame"), ballFrame = try id(.frame, "ball-frame")
        let rootProperties = try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .identity, policy: inertiaPolicy)
        let ballProperties = try MassProperties3D(mass: 2, centerOfMass: Vector3(comX, 0, 0),
            inertiaAtCenter: Matrix3(ix, ixy, 0, ixy, iy, 0, 0, 0, iz), policy: inertiaPolicy)
        let root = try BodyRecord3D(id: rootID, frame: rootFrame, mode: .static, bodyToWorld: .identity,
            representations: representations, inertia: InertialRepresentation3D(properties: rootProperties, provenance: provenance, quality: .exact))
        let ball = try BodyRecord3D(id: ballID, frame: ballFrame, mode: .dynamic,
            bodyToWorld: RigidTransform(rotation: .identity, translation: Vector3(0, 0, 1)), representations: representations,
            inertia: InertialRepresentation3D(properties: ballProperties, provenance: provenance, quality: .exact))
        var bodies = [KinematicBody(body: root), KinematicBody(body: ball)]
        let ballJoint = try JointRecord(id: id(.joint, "ball-motion"), parentBody: rootID, childBody: ballID,
            parentAnchor: JointAnchor(frame: id(.frame, "ball-parent"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: id(.frame, "ball-child"), placement: .fixed(.identity)),
            manifold: JointManifold(normalOnly ? .prismatic(axis: .unitZ) : .sixDOF))
        var records = [ballJoint], anchors: [PrescribedAnchorState] = []
        var inertias = [try RigidBodyInertia(body: rootID, frame: rootFrame, properties: rootProperties),
                       try RigidBodyInertia(body: ballID, frame: ballFrame, properties: ballProperties)]
        var planeBody = rootID
        if let wallSpeed {
            planeBody = try id(.body, "wall")
            let frame = try id(.frame, "wall-frame"), anchor = try id(.frame, "wall-parent")
            let wall = try BodyRecord3D(id: planeBody, frame: frame, mode: .prescribedKinematic, bodyToWorld: .identity,
                representations: representations, inertia: InertialRepresentation3D(properties: rootProperties, provenance: provenance, quality: .exact))
            bodies.append(KinematicBody(body: wall)); inertias.append(try RigidBodyInertia(body: planeBody, frame: frame, properties: rootProperties))
            records.append(try JointRecord(id: id(.joint, "wall-motion"), parentBody: rootID, childBody: planeBody,
                parentAnchor: JointAnchor(frame: anchor, placement: .prescribed),
                childAnchor: JointAnchor(frame: id(.frame, "wall-child"), placement: .fixed(.identity)), manifold: JointManifold(.fixed)))
            anchors.append(try PrescribedAnchorState(frame: anchor, time: 0.5,
                motion: FrameMotion(pose: .identity, velocity: SpatialMotion(angular: .zero, linear: Vector3(wallSpeed, 0, 0)), acceleration: FrameMotion.zeroMotion)))
        }
        let tree = try KinematicTree(bodies: bodies, joints: records, root: rootID, rootBase: .fixed, worldFrame: world, revision: 7,
            capacity: KinematicCapacity(maximumBodies: 4, maximumVelocities: 6, maximumJacobianScalars: 144))
        let state = try KinematicState(revision: 7, time: 0.5, q: normalOnly ? [1] : [0, 0, 1, 1, 0, 0, 0],
            v: normalOnly ? [vz] : [vx, vy, vz, 0, 0, 0], acceleration: [Double](repeating: 0, count: normalOnly ? 1 : 6), prescribedAnchors: anchors)
        let snapshot = try TreeKinematicsEvaluator().evaluate(tree, state: state, policy: joints())
        let filter = ColliderFilter(enabled: true, layerBits: 1, maskBits: 1, isTrigger: false)
        func proxy(_ key: String, body: EntityID, shape: CollisionShape) throws -> CollisionProxy {
            try CollisionProxy(colliderID: id(.collider, key), bodyID: body, frameID: world, geometryRevision: 9, frameRevision: 7,
                shape: shape, margin: 0, representations: representations, expectedSourceRevision: 7, resolution: .analytic,
                pose: snapshot.body(body).motion.pose, filter: filter)
        }
        let first = try proxy("plane", body: planeBody, shape: .halfSpace), second = try proxy("sphere", body: ballID, shape: .sphere(radius: 1))
        var work = CollisionWork(budget: try CollisionBudget(scalarStorage: 1024, operations: 10_000, iterations: 100, records: 4))
        let geometry: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        let witness = try geometry.witness(first: first, second: second,
            policy: CollisionQueryPolicy(absoluteLengthTolerance: 1e-11, relativeLengthTolerance: 1e-11, referenceLength: 1, maximumApproximationError: 0), work: &work)
        return try FrictionalImpulseInput(tree: tree, state: state, inertias: inertias, collision: try CollisionSnapshot(proxies: [first, second], revision: 9),
            expectedCollisionRevision: 9, contact: ImpulseContactBinding(eventID: 41, witness: witness, firstProxyIndex: 0, secondProxyIndex: 1,
                firstColliderToBody: .identity, secondColliderToBody: .identity, law: law(e: e, threshold: threshold, compliant: compliant)),
            basis: ContactBasis(frame: ModelReference(id: world, revision: 7), contactToQuery: basisRotation))
    }
    public static func near(_ actual: Double, _ expected: Double, _ message: String) throws {
        guard actual.isFinite, expected.isFinite, abs(actual - expected) <= 1e-8 else {
            throw FrictionalImpulseQualificationError.assertion(message + ": " + String(actual) + " versus " + String(expected))
        }
    }
    public static func vector(_ actual: Vector3, _ x: Double, _ y: Double, _ z: Double, _ message: String) throws {
        try near(actual.x, x, message + " X"); try near(actual.y, y, message + " Y"); try near(actual.z, z, message + " Z")
    }
    public static func require(_ predicate: Bool, _ message: String) throws {
        guard predicate else { throw FrictionalImpulseQualificationError.assertion(message) }
    }
}
