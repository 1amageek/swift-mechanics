import SwiftMechanics

struct AffineRigidGravityQualificationFixture: Sendable {
    struct Point: Sendable { let mass: Double; let position: Vector3 }
    struct Integral: Sendable {
        let force: Vector3
        let torque: Vector3
        let potential: Double
        let mechanicalPower: Double
        let explicitRate: Double
    }
    let model: CompiledMechanicalModel
    let points: [Point]
    let inertias: [RigidBodyInertia]
    let body: EntityID
    let center: Vector3
    let prescribed: Bool

    init(prescribed: Bool = false) throws {
        self.prescribed = prescribed
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        center = try Vector3(0.4,-0.3,0.2)
        var distribution: [Point] = []
        for (mass, radius) in [(1.0,try Vector3(1,0.2,-0.1)),(2.0,try Vector3(0.3,0.8,0.25)),(3.0,try Vector3(-0.2,0.4,1.1))] {
            distribution.append(Point(mass: mass, position: try center.adding(radius)))
            distribution.append(Point(mass: mass, position: try center.subtracting(radius)))
        }
        points = distribution
        var mass = 0.0, tensor = Matrix3.zero
        for point in distribution {
            mass += point.mass
            let r = try point.position.subtracting(center)
            let term = try Matrix3(r.y*r.y+r.z*r.z,-r.x*r.y,-r.x*r.z,
                                   -r.y*r.x,r.x*r.x+r.z*r.z,-r.y*r.z,
                                   -r.z*r.x,-r.z*r.y,r.x*r.x+r.y*r.y).scaled(by: point.mass)
            tensor = try tensor.adding(term)
        }
        let properties = try MassProperties3D(mass: mass, centerOfMass: center, inertiaAtCenter: tensor, policy: inertiaPolicy)
        body = try EntityID(kind: .body, key: "gravity-body")
        let initialPose: RigidTransform
        if prescribed {
            initialPose = try Self.anchor(time: 2).motion.pose.composed(with:
                RigidTransform(rotation: UnitQuaternion(axis: .unitZ, angle: 0.4), translation: .zero))
        } else { initialPose = .identity }
        let record = try Self.body(body: body, properties: properties, mode: .dynamic, pose: initialPose)
        var bodies: [MechanicalBody] = [.spatial(record)], joints: [MechanicalJoint] = []
        var root = body
        if prescribed {
            root = try EntityID(kind: .body, key: "gravity-root")
            let rootProperties = try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .identity, policy: inertiaPolicy)
            bodies.insert(.spatial(try Self.body(body: root, properties: rootProperties, mode: .static)), at: 0)
            let joint = try JointRecord(id: EntityID(kind: .joint, key: "gravity-hinge"), parentBody: root, childBody: body,
                parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "gravity-prescribed"), placement: .prescribed),
                childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "gravity-child"), placement: .fixed(.identity)),
                manifold: JointManifold(.revolute(axis: .unitZ)))
            joints = [MechanicalJoint(record: joint, authority: .dynamicState)]
        }
        let q: [Double] = prescribed ? [0.4] : [0,0,0,1,0,0,0]
        let v = [Double](repeating: 0, count: prescribed ? 1 : 6)
        let anchors = prescribed ? [try Self.anchor(time: 2)] : []
        let descriptor = try MechanicalDescriptor(identity: "affine-rigid-gravity-independent", revision: 1,
            bodies: bodies, joints: joints, root: root, rootBase: prescribed ? .fixed : .spatialFloating,
            rootAuthority: prescribed ? .fixed : .dynamicState, worldFrame: EntityID(kind: .frame, key: "gravity-world"),
            initialState: KinematicState(revision: 1, time: 2, q: q, v: v, acceleration: v, prescribedAnchors: anchors),
            representationRequirements: [], features: [], extensions: [])
        let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        model = try compiler.compile(descriptor, policy: CompilationPolicy(
            kinematicCapacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 6, maximumJacobianScalars: 72),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 100, maximumIdentifierBytes: 4096, maximumSparsityEntries: 1024,
            maximumDependencyEntries: 1024, maximumExtensionRecords: 0, maximumDiagnostics: 20,
            extensionBudget: NumericalBudget(scalarStorage: 2048, arithmeticOperations: 100000, iterations: 100), target: Self.target))
        var inventory: [RigidBodyInertia] = []
        for treeBody in model.tree.bodies {
            guard let original = model.descriptor.bodies.first(where: { $0.id == treeBody.id }),
                  case .spatial(let originalRecord) = original, let inertia = originalRecord.inertia else {
                throw AffineRigidGravityQualificationError.assertion("Missing original compiled complete inertia")
            }
            inventory.append(try RigidBodyInertia(body: originalRecord.id, frame: originalRecord.frame, properties: inertia.properties))
        }
        inertias = inventory
    }

    private static func body(body: EntityID, properties: MassProperties3D, mode: BodyMotionMode,
                             pose: RigidTransform = .identity) throws -> BodyRecord3D {
        try BodyRecord3D(id: body, frame: EntityID(kind: .frame, key: body.key+"-frame"), mode: mode,
            bodyToWorld: pose, representations: BodyRepresentations(),
            inertia: InertialRepresentation3D(properties: properties,
                provenance: SourceProvenance(source: "independent-point-integral", revision: 1), quality: .exact))
    }

    private static var target: CompilerTarget {
        #if arch(wasm32)
        #if hasFeature(Embedded)
        .embeddedWasiPreview1
        #else
        .wasiPreview1
        #endif
        #else
        .nativeCPU
        #endif
    }

    static func anchor(time: Double) throws -> PrescribedAnchorState {
        try PrescribedAnchorState(frame: EntityID(kind: .frame, key: "gravity-prescribed"), time: time,
            motion: FrameMotion(pose: RigidTransform(rotation: UnitQuaternion(axis: .unitX, angle: 0.3), translation: Vector3(0.7,-0.2,0.5)),
                velocity: SpatialMotion(angular: Vector3(0.2,-0.4,0.3), linear: Vector3(1.1,-0.5,0.8)),
                acceleration: FrameMotion.zeroMotion))
    }

    func input(position: Vector3 = .zero, rotation: UnitQuaternion = .identity,
               linearVelocity: Vector3 = .zero, bodyAngularVelocity: Vector3 = .zero,
               time: Double = 2, field: AffineGravity? = nil) throws -> AffineRigidGravityInput {
        let q = prescribed ? [0.4] : [position.x,position.y,position.z,rotation.w,rotation.x,rotation.y,rotation.z]
        let v = prescribed ? [0.7] : [linearVelocity.x,linearVelocity.y,linearVelocity.z,
                                     bodyAngularVelocity.x,bodyAngularVelocity.y,bodyAngularVelocity.z]
        let anchors = prescribed ? [try Self.anchor(time: time)] : []
        let state = try model.makeState(KinematicState(revision: 1, time: time, q: q, v: v,
            acceleration: [Double](repeating: 0, count: v.count), prescribedAnchors: anchors))
        guard let inertia = inertias.first(where: { $0.body == body }) else {
            throw AffineRigidGravityQualificationError.assertion("Target inertia missing")
        }
        let actualField: AffineGravity
        if let field { actualField = field } else { actualField = try self.field() }
        return AffineRigidGravityInput(snapshot: try model.evaluate(state), inertia: inertia, field: actualField,
            expectedRevision: 1, expectedTimeSeconds: time, gradientTimeDerivative: .zero)
    }

    func field(timeDerivative: Vector3 = .zero) throws -> AffineGravity {
        try AffineGravity(frame: model.tree.worldFrame, accelerationAtOrigin: Vector3(0.6,-9.2,0.4),
            gradient: Matrix3(0.7,0.2,-0.15,0.2,-0.4,0.3,-0.15,0.3,0.9), uniformTimeDerivative: timeDerivative)
    }

    func integral(_ input: AffineRigidGravityInput, reference: Vector3, drift: Bool = false) throws -> Integral {
        let body = try input.snapshot.body(self.body)
        let motion = drift ? body.prescribedDriftVelocity : body.motion.velocity
        var force = Vector3.zero, torque = Vector3.zero, potential = 0.0, power = 0.0, explicit = 0.0
        for point in points {
            let offset = try body.motion.pose.transforming(direction: point.position)
            let x = try body.motion.pose.translation.adding(offset)
            let gx = try input.field.gradient.applying(to: x)
            let f = try input.field.accelerationAtOrigin.adding(gx).scaled(by: point.mass)
            force = try force.adding(f)
            torque = try torque.adding(x.subtracting(reference).cross(f))
            potential -= try point.mass*(input.field.accelerationAtOrigin.dot(x)+x.dot(gx)/2)
            power += try f.dot(motion.velocity(at: offset))
            explicit -= try point.mass*input.field.uniformTimeDerivative.dot(x)
        }
        return Integral(force: force, torque: torque, potential: potential, mechanicalPower: power, explicitRate: explicit)
    }

    func worldMomentIntegral(_ input: AffineRigidGravityInput, differentiated: Bool) throws -> Matrix3 {
        let body = try input.snapshot.body(self.body)
        var result = Matrix3.zero
        for point in points {
            let r = try body.motion.pose.transforming(direction: point.position.subtracting(center))
            let value: Matrix3
            if differentiated {
                let v = try body.motion.velocity.angular.cross(r)
                value = try Matrix3(2*r.x*v.x,v.x*r.y+r.x*v.y,v.x*r.z+r.x*v.z,
                    v.y*r.x+r.y*v.x,2*r.y*v.y,v.y*r.z+r.y*v.z,
                    v.z*r.x+r.z*v.x,v.z*r.y+r.z*v.y,2*r.z*v.z)
            } else {
                value = try Matrix3(r.x*r.x,r.x*r.y,r.x*r.z,r.y*r.x,r.y*r.y,r.y*r.z,r.z*r.x,r.z*r.y,r.z*r.z)
            }
            result = try result.adding(value.scaled(by: point.mass))
        }
        return result
    }

    static func policy(bodies: Int = 2, identityBytes: Int = 128) throws -> AffineRigidGravityPolicy {
        try AffineRigidGravityPolicy(maximumBodies: bodies, maximumIdentityBytes: identityBytes,
            powerAgreement: NumericalTolerance(absolute: 1e-9, relative: 1e-10))
    }
    static func work(units: Int = 100000, scalars: Int = 256, cancelled: @escaping @Sendable () -> Bool = { false }) throws -> LoadWork {
        LoadWork(budget: try LoadBudget(maximumWork: units, maximumScalars: scalars, isCancelled: cancelled))
    }
    static func numericalWork() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 100000, arithmeticOperations: 1000000, iterations: 1000))
    }
}
