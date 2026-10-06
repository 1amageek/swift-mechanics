import SwiftMechanics

/// Genuine compiled shafts with an explicitly supplied sampled contact catalog and constitutive law.
/// The catalog represents external patches, not an involute tooth or CAD mesh.
final class MaterialToothContactProbeContext: Sendable {
    enum NormalLaw: Equatable, Sendable {
        case linear, dampedLinear, hertz, huntCrossley
    }

    enum Geometry: Equatable, Sendable {
        case spheres, sphereBox
    }

    let model: ToothContactModel
    let initial: MaterialToothContactState
    let policy: ToothContactPolicy
    let budget: NumericalBudget
    let maximumSupplierCalls: Int = 100_000
    let constructionWork: ToothContactWork
    let initialWork: ToothContactWork
    let inputBody: EntityID
    let outputBody: EntityID
    let inputCoordinateIndex: Int
    let outputCoordinateIndex: Int
    let firstContactIsInput: Bool
    let worldRotation: UnitQuaternion
    let mixedAxes: Bool
    let geometry: Geometry

    @inline(never)
    init(normal: NormalLaw = .linear, geometry: Geometry = .spheres,
         rotated: Bool = false, mixedAxes: Bool = true,
         friction: Bool = true, cohesion: Bool = true, resistance: Bool = true,
         inputInertia: Double = 1, outputInertia: Double = 1,
         inputDrive: Double = -2, outputDrive: Double = -0.25,
         inputVelocity: Double = 0.4, outputVelocity: Double = -0.2,
         sourceRevision: UInt64 = 1) throws {
        let rotation = rotated ? try UnitQuaternion(axis: Vector3(1, 2, 3), angle: 0.4) : .identity
        let recipe = try Recipe(rotation: rotation, mixedAxes: mixedAxes,
            inputInertia: inputInertia, outputInertia: outputInertia)
        let source = try Self.source(recipe, normal: normal, geometry: geometry,
            friction: friction, cohesion: cohesion, resistance: resistance,
            inputDrive: inputDrive, outputDrive: outputDrive, revision: sourceRevision)
        let seed = try Self.seed(source, inputVelocity: inputVelocity, outputVelocity: outputVelocity)
        model = source.model
        initial = seed.state
        policy = source.policy
        budget = source.work.budget
        constructionWork = source.work
        initialWork = seed.work
        inputBody = recipe.inputBody
        outputBody = recipe.outputBody
        inputCoordinateIndex = source.inputIndex
        outputCoordinateIndex = source.outputIndex
        firstContactIsInput = model.teeth[model.contacts[0].firstProxy].proxy.geometry.bodyID == inputBody
        worldRotation = rotation
        self.mixedAxes = mixedAxes
        self.geometry = geometry
    }

    func makeWork() throws(ToothContactError) -> ToothContactWork {
        try ToothContactWork(budget: budget, maximumSupplierCalls: maximumSupplierCalls)
    }

    @inline(never)
    func makeService() -> any MaterialToothContactEvolving {
        ReferenceToothContactEvolution(model: model, current: CompliantContactCurrentEvaluator())
    }

    @inline(never)
    func initialState(q: [Double], v: [Double], time: Double = 0,
                      work: inout ToothContactWork) throws(ToothContactError) -> MaterialToothContactState {
        try makeService().initialMaterial(time: time, q: q, v: v, policy: policy, work: &work)
    }

    @inline(never)
    func step(accepted: MaterialToothContactState, timeStep: Double,
              work: inout ToothContactWork) throws(ToothContactError) -> MaterialToothContactState {
        try makeService().stepMaterial(accepted: accepted, timeStep: timeStep, policy: policy, work: &work)
    }

    @inline(never)
    func advance(accepted: MaterialToothContactState, to time: Double, timeStep: Double,
                 work: inout ToothContactWork) throws(MaterialToothContactFailure) -> MaterialToothContactAdvance {
        try makeService().advanceMaterial(accepted: accepted, to: time, timeStep: timeStep, policy: policy, work: &work)
    }

    /// Rich compiler evidence is retained by an immutable owner across the model-construction phase.
    private final class Recipe: Sendable {
        let compiled: CompiledMechanicalModel
        let inputBody: EntityID
        let outputBody: EntityID

        @inline(never)
        init(rotation: UnitQuaternion, mixedAxes: Bool, inputInertia: Double, outputInertia: Double) throws {
            inputBody = try EntityID(kind: .body, key: "material-tooth-public-input")
            outputBody = try EntityID(kind: .body, key: "material-tooth-public-output")
            compiled = try MaterialToothContactProbeContext.compile(rotation: rotation, mixedAxes: mixedAxes,
                inputInertia: inputInertia, outputInertia: outputInertia)
        }
    }

    private final class Source: Sendable {
        let model: ToothContactModel
        let policy: ToothContactPolicy
        let work: ToothContactWork
        let inputIndex: Int
        let outputIndex: Int

        init(model: ToothContactModel, policy: ToothContactPolicy, work: ToothContactWork,
             inputIndex: Int, outputIndex: Int) {
            self.model = model; self.policy = policy; self.work = work
            self.inputIndex = inputIndex; self.outputIndex = outputIndex
        }
    }

    private final class Seed: Sendable {
        let state: MaterialToothContactState
        let work: ToothContactWork
        init(state: MaterialToothContactState, work: ToothContactWork) {
            self.state = state; self.work = work
        }
    }

    @inline(never)
    private static func seed(_ source: Source, inputVelocity: Double, outputVelocity: Double) throws -> Seed {
        var velocity = [Double](repeating: 0, count: 2)
        velocity[source.inputIndex] = inputVelocity
        velocity[source.outputIndex] = outputVelocity
        var work = try ToothContactWork(budget: source.work.budget, maximumSupplierCalls: source.work.maximumSupplierCalls)
        let service: any MaterialToothContactEvolving = ReferenceToothContactEvolution(model: source.model,
            current: CompliantContactCurrentEvaluator())
        let state = try service.initialMaterial(time: 0, q: [0, 0], v: velocity, policy: source.policy, work: &work)
        return Seed(state: state, work: work)
    }

    @inline(never)
    private static func source(_ recipe: Recipe, normal: NormalLaw, geometry: Geometry,
        friction: Bool, cohesion: Bool, resistance: Bool, inputDrive: Double, outputDrive: Double,
        revision: UInt64) throws -> Source {
        let compiled = recipe.compiled
        let inputJoint = try EntityID(kind: .joint, key: "material-tooth-public-input-joint")
        let outputJoint = try EntityID(kind: .joint, key: "material-tooth-public-output-joint")
        guard let input = compiled.tree.layout.joints.first(where: { $0.joint == inputJoint }),
              let output = compiled.tree.layout.joints.first(where: { $0.joint == outputJoint }),
              input.positions.count == 1, input.velocities.count == 1,
              output.positions.count == 1, output.velocities.count == 1,
              input.positions.start == input.velocities.start,
              output.positions.start == output.velocities.start else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let policy = try ToothContactProbeContext.makePolicy()
        let budget = try NumericalBudget(scalarStorage: 2_000_000, arithmeticOperations: 100_000_000, iterations: 100_000)
        var work = try ToothContactWork(budget: budget, maximumSupplierCalls: 100_000)
        let teeth = try proxies(recipe, geometry: geometry, revision: revision)
        let pair = try ToothContactPair(key: "material-tooth-public-complete-one-pair", firstProxy: 0, secondProxy: 1,
            law: law(normal: normal, friction: friction, cohesion: cohesion, resistance: resistance, revision: revision),
            firstMaterialTangent: ToothMaterialTangent(directionInCollider: .unitZ))
        var inertias: [RigidBodyInertia] = []
        for body in compiled.tree.bodies {
            guard let descriptor = compiled.descriptor.bodies.first(where: { $0.id == body.id }),
                  case .spatial(let record) = descriptor, let representation = record.inertia else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            inertias.append(try RigidBodyInertia(body: body.id, frame: record.frame, properties: representation.properties))
        }
        var drive = [Double](repeating: 0, count: 2)
        drive[input.velocities.start] = inputDrive
        drive[output.velocities.start] = outputDrive
        let model = try ToothContactModel(source: SourceProvenance(source: "external material tooth patch catalog", revision: revision),
            tree: compiled.tree, referenceCoordinates: [0, 0], inertias: inertias, teeth: teeth, contacts: [pair],
            driveForce: drive, jointPolicy: compiled.policy.jointPolicy, policy: policy, work: &work)
        return Source(model: model, policy: policy, work: work,
            inputIndex: input.velocities.start, outputIndex: output.velocities.start)
    }

    @inline(never)
    private static func proxies(_ recipe: Recipe, geometry: Geometry, revision: UInt64) throws -> [ToothProxyBinding] {
        let compiled = recipe.compiled
        var result: [ToothProxyBinding] = []
        for body in compiled.tree.bodies.dropFirst() {
            let isInput = body.id == recipe.inputBody
            guard isInput || body.id == recipe.outputBody else { throw FoundationVerificationError.analyticCheckFailed }
            let local = try RigidTransform(rotation: .identity, translation: Vector3(isInput ? 1 : -1, isInput ? 0.25 : -0.25, 0))
            let pose = try compiled.initialSnapshot.body(body.id).motion.pose.composed(with: local)
            let shape: CollisionShape
            switch geometry {
            case .spheres: shape = .sphere(radius: 0.3)
            case .sphereBox: shape = isInput ? .sphere(radius: 0.3) : .box(halfExtents: try Vector3(0.4, 0.3, 0.4))
            }
            let representation = try GeometryRepresentation(kind: .collisionGeometry,
                assetKey: isInput ? "material-tooth-public-input-patch" : "material-tooth-public-output-patch",
                provenance: SourceProvenance(source: "external sampled material contact patches", revision: revision),
                quality: .approximation(maximumDeviationMeters: 0.001))
            let proxy = try CollisionProxy(colliderID: EntityID(kind: .collider,
                key: isInput ? "material-tooth-public-input-collider" : "material-tooth-public-output-collider"),
                bodyID: body.id, frameID: compiled.tree.worldFrame, geometryRevision: revision, frameRevision: compiled.tree.revision,
                shape: shape, margin: 0, representations: BodyRepresentations(collisionGeometry: representation),
                expectedSourceRevision: revision, resolution: .sampled(maximumFeatureSpacingMeters: 0.05), pose: pose,
                filter: ColliderFilter(enabled: true, layerBits: 1, maskBits: 1, isTrigger: false))
            result.append(ToothProxyBinding(toothID: isInput ? 2001 : 2002, proxy: proxy, colliderToBody: local))
        }
        return result
    }

    @inline(never)
    private static func law(normal: NormalLaw, friction: Bool, cohesion: Bool,
                            resistance: Bool, revision: UInt64) throws -> ContactLawPair {
        let anisotropy = try ContactFrictionParameters(staticFirst: 0.9, staticSecond: 0.6,
            dynamicFirst: 0.5, dynamicSecond: 0.3, tangentialStiffness: 20, transitionSpeed: 0.1)
        let resistanceParameters = try ContactResistanceParameters(rollingCoefficient: resistance ? 0.1 : 0,
            spinningCoefficient: resistance ? 0.2 : 0, angularRegularization: 0.1)
        let cohesionLaw: ContactCohesionLaw = cohesion ? .reversibleLinear(tensileLimit: 0.3, range: 0.2) : .none
        func material(_ name: String) throws -> ContactMaterial {
            try ContactMaterial(reference: ModelReference(id: EntityID(kind: .material, key: "material-tooth-public-" + name), revision: revision),
                youngModulus: 200, poissonsRatio: 0, linearStiffness: 20,
                normalDamping: normal == .dampedLinear ? 2 : 0,
                huntCrossleyAlpha: normal == .huntCrossley ? 0.2 : 0,
                friction: friction ? .elasticCoulomb(anisotropy) : .none,
                resistance: resistanceParameters, cohesion: cohesionLaw)
        }
        let selection: ContactNormalSelection
        switch normal {
        case .linear, .dampedLinear: selection = .linear(maximumPenetration: 0.8, maximumNormalSpeed: 100)
        case .hertz: selection = .hertz(effectiveRadius: 1, maximumPenetration: 0.8, maximumNormalSpeed: 100)
        case .huntCrossley: selection = .huntCrossley(effectiveRadius: 1, maximumPenetration: 0.8, maximumNormalSpeed: 100)
        }
        var work = ContactWork(budget: try ContactBudget(operations: 100_000, scalarStorage: 10_000, records: 1))
        let pairing: any ContactMaterialPairing = SeriesContactPairing()
        return try pairing.combine(first: material("first-material"), second: material("second-material"),
            selection: selection, lossPolicy: .compliantDampingOnly, resistanceRadius: 0.3, override: nil, work: &work)
    }

    @inline(never)
    private static func body(_ name: String, position: Vector3, rotation: UnitQuaternion,
                             moment: Double, mode: BodyMotionMode) throws -> BodyRecord3D {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        return try BodyRecord3D(id: EntityID(kind: .body, key: "material-tooth-public-" + name),
            frame: EntityID(kind: .frame, key: "material-tooth-public-" + name + "-frame"), mode: mode,
            bodyToWorld: RigidTransform(rotation: rotation, translation: rotation.rotating(position)), representations: BodyRepresentations(),
            inertia: InertialRepresentation3D(properties: MassProperties3D(mass: 1, centerOfMass: .zero,
                inertiaAtCenter: Matrix3(moment, 0, 0, 0, moment, 0, 0, 0, moment),
                policy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)),
                provenance: SourceProvenance(source: "caller supplied isotropic shaft inertia", revision: 1), quality: .exact))
    }

    @inline(never)
    private static func descriptor(rotation: UnitQuaternion, mixedAxes: Bool,
                                   inputInertia: Double, outputInertia: Double) throws -> MechanicalDescriptor {
        let root = try body("root", position: .zero, rotation: rotation, moment: 1, mode: .static)
        let input = try body("input", position: .zero, rotation: rotation, moment: inputInertia, mode: .dynamic)
        let output = try body("output", position: Vector3(2, 0, 0), rotation: rotation, moment: outputInertia, mode: .dynamic)
        let inputJoint = try joint("input", root: root.id, child: input.id, offset: .zero, axis: .unitZ)
        let outputJoint = try joint("output", root: root.id, child: output.id,
            offset: Vector3(2, 0, 0), axis: mixedAxes ? .unitY : .unitZ)
        return try MechanicalDescriptor(identity: "material-tooth-public-two-shafts", revision: 1,
            bodies: [.spatial(output), .spatial(root), .spatial(input)],
            joints: [MechanicalJoint(record: outputJoint, authority: .dynamicState), MechanicalJoint(record: inputJoint, authority: .dynamicState)],
            root: root.id, rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: EntityID(kind: .frame, key: "material-tooth-public-world"),
            initialState: KinematicState(revision: 1, time: 0, q: [0, 0], v: [0, 0], acceleration: [0, 0]),
            representationRequirements: [], features: [], extensions: [])
    }

    private static func joint(_ name: String, root: EntityID, child: EntityID, offset: Vector3, axis: Vector3) throws -> JointRecord {
        try JointRecord(id: EntityID(kind: .joint, key: "material-tooth-public-" + name + "-joint"), parentBody: root, childBody: child,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "material-tooth-public-" + name + "-parent"),
                placement: .fixed(RigidTransform(rotation: .identity, translation: offset))),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "material-tooth-public-" + name + "-child"), placement: .fixed(.identity)),
            manifold: JointManifold(.revolute(axis: axis)))
    }

    @inline(never)
    private static func compile(rotation: UnitQuaternion, mixedAxes: Bool,
                                inputInertia: Double, outputInertia: Double) throws -> CompiledMechanicalModel {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 3, maximumVelocities: 2, maximumJacobianScalars: 36),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0), translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 40, maximumIdentifierBytes: 4096, maximumSparsityEntries: 36, maximumDependencyEntries: 300,
            maximumExtensionRecords: 0, maximumDiagnostics: 4,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
        let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        return try compiler.compile(descriptor(rotation: rotation, mixedAxes: mixedAxes,
            inputInertia: inputInertia, outputInertia: outputInertia), policy: policy)
    }
}
