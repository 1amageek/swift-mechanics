import SwiftMechanics

public enum TimeParameterizationQualificationFixtures {
    public static let revision: UInt64 = 41
    public static let sourceID = "original-prismatic-physical-source"
    public static let pathID = "original-prismatic-waypoints"

    public static func translated<T>(_ operation: () throws -> T) throws(TimeParameterizationQualificationError) -> T {
        do { return try operation() }
        catch let error as TimeParameterizationQualificationError { throw error }
        catch let error as RetimingError { throw .retiming(error) }
        catch let error as CoreError { throw .core(error) }
        catch let error as ModelError { throw .model(error) }
        catch let error as JointError { throw .joint(error) }
        catch let error as DynamicsError { throw .dynamics(error) }
        catch let error as NumericalError { throw .numerical(error) }
        catch let error as LoadError { throw .load(error) }
        catch { throw .unexpectedSupplier }
    }
    public static func id(_ kind: EntityKind, _ key: String) throws(TimeParameterizationQualificationError) -> EntityID {
        try translated { try EntityID(kind: kind, key: "retiming-" + key) }
    }
    public static func tolerance() throws(TimeParameterizationQualificationError) -> NumericalTolerance {
        try translated { try NumericalTolerance(absolute: 1e-10, relative: 1e-10) }
    }
    public static func body(_ key: String, mass: Double) throws(TimeParameterizationQualificationError) -> (KinematicBody, RigidBodyInertia) {
        try translated {
            let properties = try MassProperties3D(mass: mass, centerOfMass: Vector3(0.1, 0.2, 0.3),
                inertiaAtCenter: Matrix3(2*mass, 0, 0, 0, 3*mass, 0, 0, 0, 4*mass),
                policy: InertiaValidationPolicy(symmetry: tolerance(), physicalityRelative: 0))
            let bodyID = try id(.body, key), frame = try id(.frame, key + "-frame")
            let original = try SourceProvenance(source: sourceID, revision: revision)
            let record = try BodyRecord3D(id: bodyID, frame: frame, mode: .dynamic, bodyToWorld: .identity,
                representations: BodyRepresentations(), inertia: InertialRepresentation3D(properties: properties, provenance: original, quality: .exact))
            return (KinematicBody(body: record), try RigidBodyInertia(body: bodyID, frame: frame, properties: properties))
        }
    }
    public static func joint(_ name: String, parent: KinematicBody, child: KinematicBody,
                             specification: JointSpecification, parentPlacement: AnchorPlacement = .fixed(.identity),
                             childPlacement: AnchorPlacement = .fixed(.identity)) throws(TimeParameterizationQualificationError) -> JointRecord {
        try translated { try JointRecord(id: id(.joint, name), parentBody: parent.id, childBody: child.id,
            parentAnchor: JointAnchor(frame: id(.frame, name + "-parent"), placement: parentPlacement),
            childAnchor: JointAnchor(frame: id(.frame, name + "-child"), placement: childPlacement), manifold: JointManifold(specification)) }
    }
    public static func tree(_ bodies: [KinematicBody], joints: [JointRecord], base: BaseLayout = .fixed) throws(TimeParameterizationQualificationError) -> KinematicTree {
        try translated { try KinematicTree(bodies: bodies, joints: joints, root: bodies[0].id, rootBase: base,
            worldFrame: id(.frame, "world"), revision: revision,
            capacity: KinematicCapacity(maximumBodies: 8, maximumVelocities: 8, maximumJacobianScalars: 384)) }
    }
    public static func coupled() throws(TimeParameterizationQualificationError) -> RetimingSource {
        try translated {
            let definitions = try [body("root", mass: 1), body("first", mass: 2), body("second", mass: 3), body("fixed-tip", mass: 5)]
            let bodies = definitions.map { $0.0 }
            let rightAngle = try UnitQuaternion(axis: .unitZ, angle: .pi/2)
            let secondRotation = try UnitQuaternion(w: 2, x: 0, y: 0, z: 1)
            let joints = try [
                joint("slide-one", parent: bodies[0], child: bodies[1], specification: .prismatic(axis: .unitX),
                    parentPlacement: .fixed(RigidTransform(rotation: rightAngle, translation: Vector3(1, 2, 3))),
                    childPlacement: .fixed(RigidTransform(rotation: .identity, translation: Vector3(0.5, 0, 0)))),
                joint("slide-two", parent: bodies[1], child: bodies[2], specification: .prismatic(axis: .unitX),
                    parentPlacement: .fixed(RigidTransform(rotation: secondRotation, translation: Vector3(0, 1, 0))),
                    childPlacement: .fixed(RigidTransform(rotation: .identity, translation: Vector3(0, 0.25, 0)))),
                joint("attachment", parent: bodies[2], child: bodies[3], specification: .fixed,
                    parentPlacement: .fixed(RigidTransform(rotation: .identity, translation: .unitX)))
            ]
            let mechanicalTree = try tree(bodies, joints: joints)
            return try RetimingSource(sourceID: sourceID, tree: mechanicalTree, inertias: definitions.map { $0.1 },
                gravity: AffineGravity(frame: mechanicalTree.worldFrame, accelerationAtOrigin: Vector3(0, -10, 0)), heldAppliedForces: [7, -2])
        }
    }
    public static func single(specification: JointSpecification = .prismatic(axis: .unitX),
                              placement: AnchorPlacement = .fixed(.identity), base: BaseLayout = .fixed,
                              gravity: Bool = true) throws(TimeParameterizationQualificationError) -> RetimingSource {
        try translated {
            let root = try body("root", mass: 1), moving = try body("single", mass: 2)
            let mechanicalTree = try tree([root.0, moving.0], joints: [joint("single-slide", parent: root.0, child: moving.0,
                specification: specification, parentPlacement: placement)], base: base)
            var held = [Double](repeating: 0, count: mechanicalTree.layout.velocityCount)
            if held.count == 1 { held[0] = 3 }
            return try RetimingSource(sourceID: sourceID, tree: mechanicalTree, inertias: [root.1, moving.1],
                gravity: gravity ? AffineGravity(frame: mechanicalTree.worldFrame, accelerationAtOrigin: Vector3(-10, 0, 0)) : nil,
                heldAppliedForces: held)
        }
    }
    public static func limit(speed: (Double, Double) = (-100, 100), acceleration: (Double, Double) = (-100, 100),
                             effort: (Double, Double) = (-1_000_000, 1_000_000)) throws(TimeParameterizationQualificationError) -> RetimingCoordinateLimits {
        try translated { try RetimingCoordinateLimits(speed: RetimingInterval(lower: speed.0, upper: speed.1),
            acceleration: RetimingInterval(lower: acceleration.0, upper: acceleration.1), effort: RetimingInterval(lower: effort.0, upper: effort.1)) }
    }
    public static func request(_ source: RetimingSource, points: [[Double]], limits: [RetimingCoordinateLimits],
                               origin: Double = 0, revision: UInt64 = TimeParameterizationQualificationFixtures.revision, identity: String = TimeParameterizationQualificationFixtures.pathID) -> RetimingRequest {
        RetimingRequest(source: source, pathID: identity, sourceRevision: revision, originTime: origin, waypoints: points, limits: limits)
    }
    public static func policy(minimum: Double = 0.01, maximum: Double = 1000, total: Double = 2000,
                              bodies: Int = 8, coordinates: Int = 8, waypoints: Int = 16,
                              cancelled: @escaping @Sendable () -> Bool = { false },
                              dynamicsCancelled: @escaping @Sendable () -> Bool = { false }) throws(TimeParameterizationQualificationError) -> RetimingPolicy {
        try translated {
            let tolerance = try tolerance()
            return try RetimingPolicy(maximumWaypoints: waypoints, maximumCoordinates: coordinates, maximumBodies: bodies,
                minimumSegmentDuration: minimum, maximumSegmentDuration: maximum, maximumTotalDuration: total,
                safetyFactor: 1 + 512*Double.ulpOfOne,
                jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
                dynamicsAdmission: DynamicsAdmission(capacity: DynamicsCapacity(maximumBodies: 8, maximumVelocities: 8,
                    maximumBodyWrenches: 0, maximumGeneralizedContributions: 1), angularVelocityTolerance: tolerance,
                    linearVelocityTolerance: tolerance, isCancelled: dynamicsCancelled), physicalAgreement: tolerance, isCancelled: cancelled)
        }
    }
    public static func numerical(operations: Int = 10_000_000, storage: Int = 1_000_000) throws(TimeParameterizationQualificationError) -> NumericalWork {
        try translated { NumericalWork(budget: try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: 1000)) }
    }
    public static func loads(work: Int = 1_000_000, cancelled: @escaping @Sendable () -> Bool = { false }) throws(TimeParameterizationQualificationError) -> LoadWork {
        try translated { LoadWork(budget: try LoadBudget(maximumWork: work, maximumScalars: 10000, isCancelled: cancelled)) }
    }
    public static func parameterize(_ request: RetimingRequest, policy: RetimingPolicy? = nil) throws(TimeParameterizationQualificationError) -> RetimedPath {
        var work = try numerical(), load = try loads()
        let admitted: RetimingPolicy
        if let policy { admitted = policy } else { admitted = try self.policy() }
        let retimer: any PhysicalPathRetiming = PrismaticQuinticRetimer()
        return try translated { try retimer.parameterize(request, policy: admitted, loadWork: &load, work: &work) }
    }
    public static func sample(_ path: RetimedPath, time: Double) throws(TimeParameterizationQualificationError) -> RetimingSample {
        var work = try numerical(), load = try loads()
        let retimer: any PhysicalPathRetiming = PrismaticQuinticRetimer()
        return try translated { try retimer.sample(path, query: RetimingQuery(sourceID: sourceID, pathID: path.pathID, sourceRevision: revision, time: time), loadWork: &load, work: &work) }
    }
}
