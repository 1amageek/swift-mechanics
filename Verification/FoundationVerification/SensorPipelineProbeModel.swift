import SwiftMechanics

/// A fresh fixed-root rotor used by the original integrator and mounted observers.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct SensorPipelineProbeModel {
    let model: CompiledMechanicalModel
    let joint: EntityID
    let mount: ObservationMount
    let equation: IntegrationProbeEquation

    @inline(never)
    init() throws {
        let inertia = 3.0
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let root = try EntityID(kind: .body, key: "sensor-pipeline-root")
        let rotor = try EntityID(kind: .body, key: "sensor-pipeline-rotor")
        let representation = try InertialRepresentation3D(
            properties: MassProperties3D(mass: 1, centerOfMass: .zero,
                inertiaAtCenter: Matrix3(inertia, 0, 0, 0, inertia, 0, 0, 0, inertia), policy: inertiaPolicy),
            provenance: SourceProvenance(source: "sensor-pipeline-declared-rotor", revision: 1), quality: .exact)
        let bodies: [MechanicalBody] = [
            .spatial(try BodyRecord3D(id: root, frame: EntityID(kind: .frame, key: "sensor-pipeline-root-frame"),
                mode: .static, bodyToWorld: .identity, representations: BodyRepresentations(), inertia: representation)),
            .spatial(try BodyRecord3D(id: rotor, frame: EntityID(kind: .frame, key: "sensor-pipeline-rotor-frame"),
                mode: .dynamic, bodyToWorld: .identity, representations: BodyRepresentations(), inertia: representation))
        ]
        joint = try EntityID(kind: .joint, key: "sensor-pipeline-hinge")
        let record = try JointRecord(id: joint, parentBody: root, childBody: rotor,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "sensor-pipeline-parent"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "sensor-pipeline-child"), placement: .fixed(.identity)),
            manifold: JointManifold(.revolute(axis: .unitZ)))
        let initial = try KinematicState(revision: 1, time: 0, q: [0], v: [2], acceleration: [2])
        let descriptor = try MechanicalDescriptor(identity: "sensor-pipeline-public-rotor", revision: 1,
            bodies: bodies, joints: [MechanicalJoint(record: record, authority: .dynamicState)],
            root: root, rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: EntityID(kind: .frame, key: "sensor-pipeline-world"), initialState: initial,
            representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(
            kinematicCapacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-9, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 20, maximumIdentifierBytes: 4096, maximumSparsityEntries: 12,
            maximumDependencyEntries: 200, maximumExtensionRecords: 0, maximumDiagnostics: 4,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
        model = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
        equation = try IntegrationProbeEquation(model: model)
        mount = try ObservationMount(sensor: EntityID(kind: .sensor, key: "sensor-pipeline-imu"), body: rotor,
            sensorFrame: EntityID(kind: .frame, key: "sensor-pipeline-imu-frame"),
            sensorToBody: RigidTransform(rotation: UnitQuaternion(axis: .unitZ, angle: .pi / 2),
                translation: Vector3(1, 0, 0)))
    }
}
