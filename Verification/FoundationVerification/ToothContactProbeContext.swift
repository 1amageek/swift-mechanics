import SwiftMechanics
#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("The verification profile must provide system scalar mathematics.")
#endif

/// External sampled sphere patches on genuine unit-inertia shafts; not an involute/CAD mesh claim.
final class ToothContactProbeContext: Sendable {
    let model: ToothContactModel
    let policy: ToothContactPolicy
    let budget: NumericalBudget
    let maximumSupplierCalls: Int = 100_000
    let inputCoordinateIndex: Int
    let outputCoordinateIndex: Int
    let inputBody: EntityID
    let outputBody: EntityID
    let firstContactIsInput: Bool
    let constructionWork: ToothContactWork

    @inline(never) init(sourceRevision: UInt64 = 1) throws {
        let compiled = try Self.compile()
        let inputBody = try EntityID(kind: .body, key: "tooth-public-input")
        let outputBody = try EntityID(kind: .body, key: "tooth-public-output")
        let inputJoint = try EntityID(kind: .joint, key: "tooth-public-input-joint")
        let outputJoint = try EntityID(kind: .joint, key: "tooth-public-output-joint")
        guard let input = compiled.tree.layout.joints.first(where: { $0.joint == inputJoint }),
              let output = compiled.tree.layout.joints.first(where: { $0.joint == outputJoint }),
              input.positions.count == 1, input.velocities.count == 1,
              output.positions.count == 1, output.velocities.count == 1,
              input.positions.start == input.velocities.start, output.positions.start == output.velocities.start else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let policy = try Self.makePolicy()
        let budget = try NumericalBudget(scalarStorage: 2_000_000,
            arithmeticOperations: 100_000_000, iterations: 100_000)
        var work = try ToothContactWork(budget: budget, maximumSupplierCalls: 100_000)
        self.model = try Self.makeModel(compiled, sourceRevision: sourceRevision,
            inputBody: inputBody, outputBody: outputBody, inputIndex: input.velocities.start,
            outputIndex: output.velocities.start, policy: policy, work: &work)
        self.policy = policy
        self.budget = budget
        self.inputCoordinateIndex = input.velocities.start
        self.outputCoordinateIndex = output.velocities.start
        self.inputBody = inputBody
        self.outputBody = outputBody
        self.firstContactIsInput = compiled.tree.bodies[1].id == inputBody
        self.constructionWork = work
    }

    func makeWork() throws(ToothContactError) -> ToothContactWork {
        try ToothContactWork(budget: budget, maximumSupplierCalls: maximumSupplierCalls)
    }

    func makeService() -> any ToothContactEvolving {
        ReferenceToothContactEvolution(model: model)
    }

    @inline(never) func initial(timeStep: Double = 0.001) throws -> ToothContactState {
        var work = try makeWork()
        return try makeService().initial(time: 0, q: [0, 0], v: [0, 0], evaluationTimeStep: timeStep,
            policy: policy, work: &work)
    }

    var expectedInitialAcceleration: [Double] {
        var result = [Double](repeating: 0, count: 2)
        result[inputCoordinateIndex] = -1
        result[outputCoordinateIndex] = 0.75
        return result
    }

    var expectedInitialGeneralizedContactForce: [Double] { [1, 1] }
    var expectedNominalInitialSeparation: Double { -0.1 }
    var expectedNominalInitialNormalForce: Double { 1 }
    var expectedNominalInitialStoredEnergy: Double { 0.05 }
    var expectedPairApproximationError: Double { 0.002 }

    /// Immutable analytic evidence uses only supplied geometry and q/v, never a consumer report.
    struct Nominal: Sendable {
        let inputCenter: Vector3
        let outputCenter: Vector3
        let inputPoint: Vector3
        let outputPoint: Vector3
        let normalInputToOutput: Vector3
        let separation: Double
        let normalForce: Double
        let storedEnergy: Double
        let forceOnInput: Vector3
        let forceOnOutput: Vector3
        let inputTorque: Vector3
        let outputTorque: Vector3
        let relativePointVelocity: Vector3
        let slipVelocity: Vector3
        let generalizedContactForce: [Double]
        let acceleration: [Double]
        let kineticEnergy: Double
        let contactPower: Double
        let drivePower: Double
        let accumulatedDriveWork: Double
    }

    @inline(never) func nominal(q: [Double], v: [Double]) throws -> Nominal {
        guard q.count == 2, v.count == 2, q.allSatisfy({ $0.isFinite }), v.allSatisfy({ $0.isFinite }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let qa = q[inputCoordinateIndex], qb = q[outputCoordinateIndex]
        let va = v[inputCoordinateIndex], vb = v[outputCoordinateIndex]
        let ca = cos(qa), sa = sin(qa), cb = cos(qb), sb = sin(qb)
        let inputCenter = try Vector3(ca - 0.25 * sa, sa + 0.25 * ca, 0)
        let outputCenter = try Vector3(2 - cb + 0.25 * sb, -sb - 0.25 * cb, 0)
        let delta = try outputCenter.subtracting(inputCenter)
        let distance = try delta.magnitude()
        guard distance > 0 else { throw FoundationVerificationError.analyticCheckFailed }
        let normal = try Vector3(delta.x / distance, delta.y / distance, 0)
        let inputPoint = try Vector3(inputCenter.x + 0.3 * normal.x, inputCenter.y + 0.3 * normal.y, 0)
        let outputPoint = try Vector3(outputCenter.x - 0.3 * normal.x, outputCenter.y - 0.3 * normal.y, 0)
        let separation = distance - 0.6, penetration = max(0, -separation)
        let normalForce = 10 * penetration
        let forceInput = try Vector3(-normalForce * normal.x, -normalForce * normal.y, 0)
        let forceOutput = try Vector3(normalForce * normal.x, normalForce * normal.y, 0)
        let torqueInput = inputPoint.x * forceInput.y - inputPoint.y * forceInput.x
        let torqueOutput = (outputPoint.x - 2) * forceOutput.y - outputPoint.y * forceOutput.x
        let inputVelocity = try Vector3(-va * inputPoint.y, va * inputPoint.x, 0)
        let outputVelocity = try Vector3(-vb * outputPoint.y, vb * (outputPoint.x - 2), 0)
        let relative = try outputVelocity.subtracting(inputVelocity)
        let normalVelocity = normal.x * relative.x + normal.y * relative.y
        let slip = try Vector3(relative.x - normal.x * normalVelocity, relative.y - normal.y * normalVelocity, 0)
        var force = [Double](repeating: 0, count: 2), acceleration = force
        force[inputCoordinateIndex] = torqueInput
        force[outputCoordinateIndex] = torqueOutput
        acceleration[inputCoordinateIndex] = -2 + torqueInput
        acceleration[outputCoordinateIndex] = -0.25 + torqueOutput
        return Nominal(inputCenter: inputCenter, outputCenter: outputCenter,
            inputPoint: inputPoint, outputPoint: outputPoint, normalInputToOutput: normal,
            separation: separation, normalForce: normalForce, storedEnergy: 5 * penetration * penetration,
            forceOnInput: forceInput, forceOnOutput: forceOutput,
            inputTorque: try Vector3(0, 0, torqueInput), outputTorque: try Vector3(0, 0, torqueOutput),
            relativePointVelocity: relative, slipVelocity: slip,
            generalizedContactForce: force, acceleration: acceleration, kineticEnergy: 0.5 * (va * va + vb * vb),
            contactPower: torqueInput * va + torqueOutput * vb, drivePower: -2 * va - 0.25 * vb,
            accumulatedDriveWork: -2 * qa - 0.25 * qb)
    }

    @inline(never) static func makePolicy(isCancelled: @escaping @Sendable () -> Bool = { false }) throws -> ToothContactPolicy {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        return try ToothContactPolicy(maximumTeeth: 2, maximumContacts: 1, maximumIdentifierBytes: 4096,
            maximumSteps: 1000, maximumFeatureSpacingMeters: 0.1,
            maximumEnergyDefect: 0.01, physicalTolerance: 1e-8,
            collision: CollisionQueryPolicy(absoluteLengthTolerance: 1e-10, relativeLengthTolerance: 1e-10,
                referenceLength: 1, maximumApproximationError: 0.002),
            contact: ContactAcceptancePolicy(absoluteEnergyTolerance: 1e-9, absolutePowerTolerance: 1e-9,
                relativeTolerance: 1e-10, referenceEnergy: 1, referencePower: 1, coneTolerance: 1e-10),
            dynamics: DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
                linearTolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-12),
                coordinateScales: [1, 1], energyScale: 1, timeScale: 1),
            admission: DynamicsAdmission(capacity: DynamicsCapacity(maximumBodies: 3, maximumVelocities: 2,
                maximumBodyWrenches: 2, maximumGeneralizedContributions: 0),
                angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance), isCancelled: isCancelled)
    }

    @inline(never) private static func makeModel(_ compiled: CompiledMechanicalModel, sourceRevision: UInt64,
        inputBody: EntityID, outputBody: EntityID, inputIndex: Int, outputIndex: Int,
        policy: ToothContactPolicy, work: inout ToothContactWork) throws -> ToothContactModel {
        let first = try proxy("input", body: inputBody, position: Vector3(1, 0.25, 0),
            world: compiled.tree.worldFrame, sourceRevision: sourceRevision)
        let second = try proxy("output", body: outputBody, position: Vector3(1, -0.25, 0),
            world: compiled.tree.worldFrame, sourceRevision: sourceRevision)
        let input = ToothProxyBinding(toothID: 1001, proxy: first,
            colliderToBody: try RigidTransform(rotation: .identity, translation: Vector3(1, 0.25, 0)))
        let output = ToothProxyBinding(toothID: 1002, proxy: second,
            colliderToBody: try RigidTransform(rotation: .identity, translation: Vector3(-1, -0.25, 0)))
        let firstIsInput = compiled.tree.bodies[1].id == inputBody
        guard firstIsInput || compiled.tree.bodies[1].id == outputBody else { throw FoundationVerificationError.analyticCheckFailed }
        let teeth = firstIsInput ? [input, output] : [output, input]
        let law = try contactLaw(sourceRevision: sourceRevision)
        let pair = try ToothContactPair(key: "tooth-public-complete-one-pair", firstProxy: 0, secondProxy: 1, law: law)
        var inertias: [RigidBodyInertia] = []
        for body in compiled.tree.bodies {
            guard let descriptor = compiled.descriptor.bodies.first(where: { $0.id == body.id }),
                  case .spatial(let record) = descriptor, let inertia = record.inertia else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            inertias.append(try RigidBodyInertia(body: body.id, frame: record.frame, properties: inertia.properties))
        }
        var drive = [Double](repeating: 0, count: 2)
        drive[inputIndex] = -2
        drive[outputIndex] = -0.25
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        return try ToothContactModel(source: SourceProvenance(source: "external sampled spherical tooth patches", revision: sourceRevision),
            tree: compiled.tree, referenceCoordinates: [0, 0], inertias: inertias, teeth: teeth, contacts: [pair],
            driveForce: drive, jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance,
                chartRankRelative: 1e-10, characteristicLengthMeters: 1), policy: policy, work: &work)
    }

    @inline(never) private static func proxy(_ name: String, body: EntityID, position: Vector3,
        world: EntityID, sourceRevision: UInt64) throws -> CollisionProxy {
        let representation = try GeometryRepresentation(kind: .collisionGeometry, assetKey: "external-tooth-sphere-" + name,
            provenance: SourceProvenance(source: "external sampled spherical tooth patches", revision: sourceRevision),
            quality: .approximation(maximumDeviationMeters: 0.001))
        return try CollisionProxy(colliderID: EntityID(kind: .collider, key: "tooth-public-" + name + "-patch"),
            bodyID: body, frameID: world, geometryRevision: sourceRevision, frameRevision: 1,
            shape: .sphere(radius: 0.3), margin: 0,
            representations: BodyRepresentations(collisionGeometry: representation), expectedSourceRevision: sourceRevision,
            resolution: .sampled(maximumFeatureSpacingMeters: 0.05),
            pose: RigidTransform(rotation: .identity, translation: position),
            filter: ColliderFilter(enabled: true, layerBits: 1, maskBits: 1, isTrigger: false))
    }

    @inline(never) private static func contactLaw(sourceRevision: UInt64) throws -> ContactLawPair {
        func material(_ name: String) throws -> ContactMaterial {
            try ContactMaterial(reference: ModelReference(id: EntityID(kind: .material, key: "tooth-public-" + name), revision: sourceRevision),
                youngModulus: 1e6, poissonsRatio: 0.25, linearStiffness: 20, normalDamping: 0, huntCrossleyAlpha: 0,
                friction: .none, resistance: ContactResistanceParameters(rollingCoefficient: 0, spinningCoefficient: 0,
                    angularRegularization: 0.1), cohesion: .none)
        }
        var work = ContactWork(budget: try ContactBudget(operations: 100_000, scalarStorage: 1000, records: 1))
        let pairing: any ContactMaterialPairing = SeriesContactPairing()
        return try pairing.combine(first: material("first-material"), second: material("second-material"),
            selection: .linear(maximumPenetration: 0.4, maximumNormalSpeed: 100),
            lossPolicy: .compliantDampingOnly, resistanceRadius: 0.3, override: nil, work: &work)
    }

    @inline(never) private static func body(_ name: String, position: Vector3, mode: BodyMotionMode) throws -> BodyRecord3D {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        return try BodyRecord3D(id: EntityID(kind: .body, key: "tooth-public-" + name),
            frame: EntityID(kind: .frame, key: "tooth-public-" + name + "-frame"), mode: mode,
            bodyToWorld: RigidTransform(rotation: .identity, translation: position), representations: BodyRepresentations(),
            inertia: InertialRepresentation3D(properties: MassProperties3D(mass: 1, centerOfMass: .zero,
                inertiaAtCenter: .identity, policy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)),
                provenance: SourceProvenance(source: "independent unit shaft inertia", revision: 1), quality: .exact))
    }

    @inline(never) private static func descriptor() throws -> MechanicalDescriptor {
        let root = try body("root", position: .zero, mode: .static)
        let input = try body("input", position: .zero, mode: .dynamic)
        let output = try body("output", position: Vector3(2, 0, 0), mode: .dynamic)
        let inputJoint = try JointRecord(id: EntityID(kind: .joint, key: "tooth-public-input-joint"),
            parentBody: root.id, childBody: input.id,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "tooth-public-input-parent"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "tooth-public-input-child"), placement: .fixed(.identity)),
            manifold: JointManifold(.revolute(axis: .unitZ)))
        let outputJoint = try JointRecord(id: EntityID(kind: .joint, key: "tooth-public-output-joint"),
            parentBody: root.id, childBody: output.id,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "tooth-public-output-parent"),
                placement: .fixed(RigidTransform(rotation: .identity, translation: Vector3(2, 0, 0)))),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "tooth-public-output-child"), placement: .fixed(.identity)),
            manifold: JointManifold(.revolute(axis: .unitZ)))
        return try MechanicalDescriptor(identity: "tooth-public-two-shafts", revision: 1,
            bodies: [.spatial(output), .spatial(root), .spatial(input)],
            joints: [MechanicalJoint(record: outputJoint, authority: .dynamicState),
                     MechanicalJoint(record: inputJoint, authority: .dynamicState)],
            root: root.id, rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: EntityID(kind: .frame, key: "tooth-public-world"),
            initialState: KinematicState(revision: 1, time: 0, q: [0, 0], v: [0, 0], acceleration: [0, 0]),
            representationRequirements: [], features: [], extensions: [])
    }

    @inline(never) private static func compile() throws -> CompiledMechanicalModel {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 3,
            maximumVelocities: 2, maximumJacobianScalars: 36),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0),
            translationTolerance: tolerance, rotationTolerance: tolerance, maximumRecords: 40,
            maximumIdentifierBytes: 4096, maximumSparsityEntries: 36, maximumDependencyEntries: 300,
            maximumExtensionRecords: 0, maximumDiagnostics: 4,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
        let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        return try compiler.compile(descriptor(), policy: policy)
    }
}
