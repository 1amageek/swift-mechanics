import SwiftMechanics

/// Real compiled shafts and striker with an original stationary affine gear relation.
final class ConstrainedImpactProbeModel: Sendable {
    let model: CompiledMechanicalModel
    let physical: CompiledKinematicState
    let constraints: QuadraticConstraintSystem
    let constraintConstructionWork: NumericalWork
    let firstRotor: EntityID
    let secondRotor: EntityID
    let striker: EntityID
    let firstRotorCoordinateIndex: Int
    let secondRotorCoordinateIndex: Int
    let strikerCoordinateIndex: Int

    @inline(never)
    init() throws {
        let compiled = try Self.compile()
        let first = try Self.id(.body, "a")
        let second = try Self.id(.body, "b")
        let striker = try Self.id(.body, "striker")
        let aJoint = try Self.id(.joint, "a")
        let bJoint = try Self.id(.joint, "b")
        let strikerJoint = try Self.id(.joint, "striker")
        guard let a = compiled.tree.layout.joints.first(where: { $0.joint == aJoint }),
              let b = compiled.tree.layout.joints.first(where: { $0.joint == bJoint }),
              let s = compiled.tree.layout.joints.first(where: { $0.joint == strikerJoint }),
              a.positions.count == 1, a.velocities.count == 1,
              b.positions.count == 1, b.velocities.count == 1,
              s.positions.count == 1, s.velocities.count == 1,
              a.positions.start == 0, a.velocities.start == 0,
              b.positions.start == 1, b.velocities.start == 1,
              s.positions.start == 2, s.velocities.start == 2 else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let relation = try Self.relation(compiled)
        model = compiled
        physical = try compiled.makeState(compiled.descriptor.initialState)
        constraints = relation.system
        constraintConstructionWork = relation.work
        firstRotor = first
        secondRotor = second
        self.striker = striker
        firstRotorCoordinateIndex = a.velocities.start
        secondRotorCoordinateIndex = b.velocities.start
        strikerCoordinateIndex = s.velocities.start
    }

    /// Source construction returns only public input; preparation owns its physical admission.
    @inline(never)
    func makeInput(restitution: Double, collisionWork: inout CollisionWork,
                   contactWork: inout ContactWork) throws -> HardImpactInput {
        let geometry = try contactGeometry()
        let query: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        let witness = try query.witness(first: geometry.first, second: geometry.second,
            policy: CollisionQueryPolicy(absoluteLengthTolerance: 1e-10, relativeLengthTolerance: 1e-10,
                referenceLength: 1, maximumApproximationError: 0), work: &collisionWork)
        let pair = try Self.law(restitution: restitution, work: &contactWork)
        let contact = ImpulseContactBinding(eventID: 41, witness: witness, firstProxyIndex: 0, secondProxyIndex: 1,
            firstColliderToBody: geometry.offset, secondColliderToBody: .identity, law: pair)
        return HardImpactInput(model: model, physical: physical, inertias: try inertias(),
            collision: try CollisionSnapshot(proxies: [geometry.first, geometry.second], revision: 1),
            expectedCollisionRevision: 1, contacts: [contact])
    }

    private final class ContactGeometry: Sendable {
        let first: CollisionProxy
        let second: CollisionProxy
        let offset: RigidTransform
        init(first: CollisionProxy, second: CollisionProxy, offset: RigidTransform) {
            self.first = first; self.second = second; self.offset = offset
        }
    }

    private final class Relation: Sendable {
        let system: QuadraticConstraintSystem
        let work: NumericalWork
        init(system: QuadraticConstraintSystem, work: NumericalWork) {
            self.system = system; self.work = work
        }
    }

    @inline(never)
    private func contactGeometry() throws -> ContactGeometry {
        let snapshot = try model.evaluate(physical)
        let offset = RigidTransform(rotation: .identity, translation: try Vector3(1, 0, 0))
        let firstPose = try snapshot.body(firstRotor).motion.pose.composed(with: offset)
        let secondPose = try snapshot.body(striker).motion.pose
        return ContactGeometry(first: try Self.proxy("rotor", body: firstRotor, pose: firstPose, world: model.tree.worldFrame),
            second: try Self.proxy("striker", body: striker, pose: secondPose, world: model.tree.worldFrame), offset: offset)
    }

    @inline(never)
    private func inertias() throws -> [RigidBodyInertia] {
        var result: [RigidBodyInertia] = []
        for body in model.tree.bodies {
            guard let descriptor = model.descriptor.bodies.first(where: { $0.id == body.id }),
                  case .spatial(let record) = descriptor, let representation = record.inertia else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            result.append(try RigidBodyInertia(body: body.id, frame: body.frame, properties: representation.properties))
        }
        return result
    }

    @inline(never)
    private static func relation(_ compiled: CompiledMechanicalModel) throws -> Relation {
        let layout = try ConstraintCoordinateLayout(coordinateIDs: [10, 20, 30], dimensions: [.angle, .angle, .length],
            scales: [1, 1, 1], timeScale: 2, revision: compiled.stamp.revision)
        var ports: [TransmissionPortBinding] = []
        for (index, name) in ["a", "b"].enumerated() {
            let jointID = try id(.joint, name)
            guard let joint = compiled.descriptor.joints.first(where: { $0.record.id == jointID }),
                  let entry = compiled.tree.layout.joints.first(where: { $0.joint == jointID }),
                  let kinematics = compiled.initialSnapshot.joints.first(where: { $0.joint == jointID }),
                  entry.positions.start == index, entry.velocities.start == index else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            ports.append(try TransmissionPortBinding(coordinateIndex: index, coordinateID: layout.coordinateIDs[index],
                body: joint.record.childBody, joint: jointID, frame: compiled.tree.worldFrame,
                manifold: joint.record.manifold, jointToReference: kinematics.parentAnchor.motion.pose,
                layoutRevision: layout.revision, modelRevision: compiled.stamp.revision))
        }
        var work = NumericalWork(budget: try NumericalBudget(scalarStorage: 100_000, arithmeticOperations: 10_000_000, iterations: 10_000))
        let compiler: any TransmissionCompiling = AffineTransmissionCompiler()
        let result = try compiler.compile(id: 9, layout: layout, ports: ports,
            relations: [TransmissionRelation(id: 7, kind: .externalGear(first: 0, second: 1, firstTeeth: 1, secondTeeth: 1,
                phase: 0, phaseScale: 1))], minimumPosition: [-10, -10, -10], maximumPosition: [10, 10, 10],
            minimumTime: 0, maximumTime: 10,
            policy: TransmissionPolicy(maximumCoordinates: 3, maximumPorts: 2, maximumRelations: 3,
                expectedLayoutRevision: compiled.stamp.revision, expectedModelRevision: compiled.stamp.revision,
                geometryTolerance: 1e-10, originalTolerance: 1e-9, powerScale: 1, powerTolerance: 1e-9), work: &work)
        return Relation(system: result.equations, work: work)
    }

    private static func id(_ kind: EntityKind, _ name: String) throws -> EntityID {
        try EntityID(kind: kind, key: "constrained-impact-public-" + name)
    }

    private static func representation() throws -> BodyRepresentations {
        try BodyRepresentations(collisionGeometry: GeometryRepresentation(kind: .collisionGeometry,
            assetKey: "constrained-impact-public-analytic-sphere",
            provenance: SourceProvenance(source: "independent constrained impact analytic input", revision: 1), quality: .exact))
    }

    private static func proxy(_ name: String, body: EntityID, pose: RigidTransform, world: EntityID) throws -> CollisionProxy {
        try CollisionProxy(colliderID: id(.collider, name), bodyID: body, frameID: world, geometryRevision: 1, frameRevision: 1,
            shape: .sphere(radius: 0.25), margin: 0, representations: representation(), expectedSourceRevision: 1,
            resolution: .analytic, pose: pose, filter: ColliderFilter(enabled: true, layerBits: 1, maskBits: 1, isTrigger: false))
    }

    @inline(never)
    private static func law(restitution: Double, work: inout ContactWork) throws -> ContactLawPair {
        func material(_ name: String) throws -> ContactMaterial {
            try ContactMaterial(reference: ModelReference(id: id(.material, name), revision: 1), youngModulus: 1e6,
                poissonsRatio: 0.2, linearStiffness: 2000, normalDamping: 0, huntCrossleyAlpha: 0, friction: .none,
                resistance: ContactResistanceParameters(rollingCoefficient: 0, spinningCoefficient: 0, angularRegularization: 0.1), cohesion: .none)
        }
        let pairing: any ContactMaterialPairing = SeriesContactPairing()
        return try pairing.combine(first: material("rotor-material"), second: material("striker-material"),
            selection: .linear(maximumPenetration: 1, maximumNormalSpeed: 100),
            lossPolicy: .separateImpact(restitution: restitution, thresholdSpeed: 0), resistanceRadius: 0.25,
            override: nil, work: &work)
    }

    @inline(never)
    private static func body(_ name: String, mode: BodyMotionMode, origin: Vector3) throws -> BodyRecord3D {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        return try BodyRecord3D(id: id(.body, name), frame: id(.frame, name + "-body"), mode: mode,
            bodyToWorld: RigidTransform(rotation: .identity, translation: origin), representations: representation(),
            inertia: InertialRepresentation3D(properties: MassProperties3D(mass: mode == .static ? 1 : 2,
                centerOfMass: .zero, inertiaAtCenter: Matrix3(2, 0, 0, 0, 2, 0, 0, 0, 2),
                policy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)),
                provenance: SourceProvenance(source: "independent constrained impact inertia", revision: 1), quality: .exact))
    }

    private static func joint(_ name: String, root: EntityID, child: EntityID, origin: Vector3,
                              manifold: JointManifold) throws -> MechanicalJoint {
        try MechanicalJoint(record: JointRecord(id: id(.joint, name), parentBody: root, childBody: child,
            parentAnchor: JointAnchor(frame: id(.frame, name + "-parent"), placement: .fixed(RigidTransform(rotation: .identity, translation: origin))),
            childAnchor: JointAnchor(frame: id(.frame, name + "-child"), placement: .fixed(.identity)), manifold: manifold), authority: .dynamicState)
    }

    @inline(never)
    private static func descriptor() throws -> MechanicalDescriptor {
        let root = try body("root", mode: .static, origin: .zero)
        let a = try body("a", mode: .dynamic, origin: .zero)
        let b = try body("b", mode: .dynamic, origin: Vector3(3, 0, 0))
        let striker = try body("striker", mode: .dynamic, origin: Vector3(1, 0.5, 0))
        let rotor = try JointManifold(.revolute(axis: .unitZ))
        let translation = try JointManifold(.prismatic(axis: .unitY))
        return try MechanicalDescriptor(identity: "constrained-impact-public-model", revision: 1,
            bodies: [.spatial(striker), .spatial(b), .spatial(root), .spatial(a)],
            joints: [joint("a", root: root.id, child: a.id, origin: .zero, manifold: rotor),
                joint("b", root: root.id, child: b.id, origin: Vector3(3, 0, 0), manifold: rotor),
                joint("striker", root: root.id, child: striker.id, origin: Vector3(1, 0, 0), manifold: translation)],
            root: root.id, rootBase: .fixed, rootAuthority: .fixed, worldFrame: id(.frame, "world"),
            initialState: KinematicState(revision: 1, time: 0.25, q: [0, 0, 0.5], v: [0, 0, -1], acceleration: [0, 0, 0]),
            representationRequirements: [], features: [], extensions: [])
    }

    @inline(never)
    private static func compile() throws -> CompiledMechanicalModel {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 4, maximumVelocities: 3, maximumJacobianScalars: 96),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0), translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 100, maximumIdentifierBytes: 10_000, maximumSparsityEntries: 1000, maximumDependencyEntries: 1000,
            maximumExtensionRecords: 10, maximumDiagnostics: 10,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
        let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        return try compiler.compile(descriptor(), policy: policy)
    }
}
