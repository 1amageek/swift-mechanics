import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
enum ReactionPathProbeContext {
    static func model() throws -> CompiledMechanicalModel {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        var bodies: [MechanicalBody] = []
        for (index, key) in ["root", "pendulum"].enumerated() {
            let properties = try MassProperties3D(mass: index == 0 ? 1 : 2,
                                                  centerOfMass: index == 0 ? .zero : .unitX,
                                                  inertiaAtCenter: index == 0 ? .identity : Matrix3(2, 0, 0, 0, 3, 0, 0, 0, 4),
                                                  policy: inertiaPolicy)
            let body = try BodyRecord3D(id: MechanismProbeContext.id(.body, key), frame: MechanismProbeContext.id(.frame, key + "-frame"),
                                        mode: index == 0 ? .static : .dynamic, bodyToWorld: .identity, representations: BodyRepresentations(),
                                        inertia: InertialRepresentation3D(properties: properties,
                                                                         provenance: SourceProvenance(source: "analytic-pendulum", revision: 1), quality: .exact))
            bodies.append(.spatial(body))
        }
        let joint = try JointRecord(id: MechanismProbeContext.id(.joint, "hinge"), parentBody: MechanismProbeContext.id(.body, "root"),
                                     childBody: MechanismProbeContext.id(.body, "pendulum"),
                                     parentAnchor: JointAnchor(frame: MechanismProbeContext.id(.frame, "hinge-parent"), placement: .fixed(.identity)),
                                     childAnchor: JointAnchor(frame: MechanismProbeContext.id(.frame, "hinge-child"), placement: .fixed(.identity)),
                                     manifold: JointManifold(.revolute(axis: .unitZ)))
        let state = try KinematicState(revision: 1, time: 0, q: [0], v: [0], acceleration: [-10.0 / 3])
        let descriptor = try MechanicalDescriptor(identity: "physical-support-pendulum", revision: 1, bodies: bodies,
                                                    joints: [MechanicalJoint(record: joint, authority: .dynamicState)],
                                                    root: MechanismProbeContext.id(.body, "root"), rootBase: .fixed, rootAuthority: .fixed,
                                                    worldFrame: MechanismProbeContext.id(.frame, "world"), initialState: state,
                                                    representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12),
                                           jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
                                           inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
                                           maximumRecords: 20, maximumIdentifierBytes: 2000, maximumSparsityEntries: 12,
                                           maximumDependencyEntries: 200, maximumExtensionRecords: 1, maximumDiagnostics: 4,
                                           extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
                                           target: FoundationVerification.compilerVerificationTarget)
        return try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
    }

    static func system(_ model: CompiledMechanicalModel, generalized: Bool = false) throws -> RigidDynamicsSystem {
        var inertias: [RigidBodyInertia] = []
        for body in model.tree.bodies {
            guard let source = model.descriptor.bodies.first(where: { $0.id == body.id }), case .spatial(let spatial) = source,
                  let inertia = spatial.inertia else { throw FoundationVerificationError.analyticCheckFailed }
            inertias.append(try RigidBodyInertia(body: body.id, frame: body.frame, properties: inertia.properties))
        }
        let input = try RigidDynamicsInput(snapshot: model.initialSnapshot, velocity: [0], inertias: inertias,
                                           gravity: AffineGravity(frame: model.tree.worldFrame, accelerationAtOrigin: Vector3(0, -10, 0)),
                                           generalizedForces: generalized ? [GeneralizedForceContribution(values: [1], channel: .actuator)] : [])
        var work = try MechanismProbeContext.work(), load = LoadWork(budget: try LoadBudget(maximumWork: 100, maximumScalars: 0))
        return try RigidEquationKernel().assemble(input, admission: MechanismProbeContext.admission(), loadWork: &load, work: &work)
    }

    static func policy() throws -> TreeReactionPolicy {
        let tolerance = try NumericalTolerance(absolute: 1e-9, relative: 1e-9)
        return try TreeReactionPolicy(maximumBodies: 2, maximumJoints: 1, maximumBodyLoads: 2,
                                      generalizedForceScales: [20], generalizedTolerance: tolerance,
                                      forceTolerance: tolerance, torqueTolerance: tolerance)
    }
}
