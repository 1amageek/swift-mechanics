import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints
import MechanicsLoads
import MechanicsDynamics
import MechanicsCollision
import MechanicsContactLaws
import MechanicsComplementarity
import MechanicsContactResponse

extension FoundationVerification {
    static func verifyContactResponse() throws {
        let world = try EntityID(kind: .frame, key: "response-world")
        let ground = try EntityID(kind: .body, key: "response-ground"), child = try EntityID(kind: .body, key: "response-child")
        let groundFrame = try EntityID(kind: .frame, key: "response-ground-frame"), childFrame = try EntityID(kind: .frame, key: "response-child-frame")
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let mass = try MassProperties3D(mass: 2, centerOfMass: .zero, inertiaAtCenter: .identity, policy: inertiaPolicy)
        let bodies = try [KinematicBody(body: BodyRecord3D(id: ground, frame: groundFrame, mode: .static, bodyToWorld: .identity, representations: BodyRepresentations(), inertia: nil)),
            KinematicBody(body: BodyRecord3D(id: child, frame: childFrame, mode: .dynamic, bodyToWorld: .identity, representations: BodyRepresentations(), inertia: InertialRepresentation3D(properties: mass, provenance: SourceProvenance(source: "analytic", revision: 1), quality: .exact)))]
        let joint = try JointRecord(id: EntityID(kind: .joint, key: "response-slider"), parentBody: ground, childBody: child,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "response-pa"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "response-ca"), placement: .fixed(.identity)), manifold: JointManifold(.prismatic(axis: .unitZ)))
        let tree = try KinematicTree(bodies: bodies, joints: [joint], root: ground, rootBase: .fixed, worldFrame: world, revision: 1,
            capacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12))
        let state = try KinematicState(revision: 1, time: 0, q: [0.9], v: [0], acceleration: [99])
        let snapshot = try TreeKinematicsEvaluator().evaluate(tree, state: state, policy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-9, characteristicLengthMeters: 1))
        let inertias = try [RigidBodyInertia(body: ground, frame: groundFrame, properties: mass), RigidBodyInertia(body: child, frame: childFrame, properties: mass)]
        var assemblyWork = try responseNumericalWork(), loadWork = LoadWork(budget: try LoadBudget(maximumWork: 100, maximumScalars: 0))
        let system = try RigidEquationKernel().assemble(RigidDynamicsInput(snapshot: snapshot, velocity: [0], inertias: inertias, gravity: nil),
            admission: DynamicsAdmission(capacity: DynamicsCapacity(maximumBodies: 2, maximumVelocities: 1, maximumBodyWrenches: 0, maximumGeneralizedContributions: 0), angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance), loadWork: &loadWork, work: &assemblyWork)
        var proxies: [CollisionProxy] = []
        for (index, body) in [ground, child].enumerated() {
            let proxy = try CollisionProxy(colliderID: EntityID(kind: .collider, key: "response-collider-" + String(index)), bodyID: body, frameID: world,
                geometryRevision: UInt64(index+3), frameRevision: 1, shape: .sphere(radius: 0.5), margin: 0,
                representations: BodyRepresentations(collisionGeometry: GeometryRepresentation(kind: .collisionGeometry, assetKey: "analytic-sphere", provenance: SourceProvenance(source: "physical", revision: 1), quality: .exact)),
                expectedSourceRevision: 1, resolution: .analytic, pose: snapshot.body(body).motion.pose,
                filter: ColliderFilter(enabled: true, layerBits: 1, maskBits: 1, isTrigger: false))
            proxies.append(proxy)
        }
        let collision = try CollisionSnapshot(proxies: proxies, revision: 2)
        var geometryWork = CollisionWork(budget: try CollisionBudget(scalarStorage: 1000, operations: 10000, iterations: 0, records: 2))
        let witness = try AnalyticCollisionQueries().witness(first: proxies[0], second: proxies[1], policy: CollisionQueryPolicy(absoluteLengthTolerance: 1e-10, relativeLengthTolerance: 1e-10, referenceLength: 1, maximumApproximationError: 0), work: &geometryWork)
        let resistance = try ContactResistanceParameters(rollingCoefficient: 0, spinningCoefficient: 0, angularRegularization: 0.1)
        let a = try ContactMaterial(reference: ModelReference(id: EntityID(kind: .material, key: "response-material-a"), revision: 1), youngModulus: 1e6, poissonsRatio: 0.2, linearStiffness: 2000, normalDamping: 0, huntCrossleyAlpha: 0, friction: .none, resistance: resistance, cohesion: .none)
        let b = try ContactMaterial(reference: ModelReference(id: EntityID(kind: .material, key: "response-material-b"), revision: 1), youngModulus: 1e6, poissonsRatio: 0.2, linearStiffness: 2000, normalDamping: 0, huntCrossleyAlpha: 0, friction: .none, resistance: resistance, cohesion: .none)
        var pairingWork = try responseContactWork()
        let pair = try SeriesContactPairing().combine(first: a, second: b, selection: .linear(maximumPenetration: 1, maximumNormalSpeed: 100), lossPolicy: .compliantDampingOnly, resistanceRadius: 0.5, override: nil, work: &pairingWork)
        let identity = try ContactIdentity(key: "response-contact", firstBody: ModelReference(id: ground, revision: 1), secondBody: ModelReference(id: child, revision: 1), frame: ModelReference(id: world, revision: 1), firstGeometryRevision: 3, secondGeometryRevision: 4, tangentLayoutRevision: 1)
        let history = try CompliantContactEvaluator().initialHistory(identity: identity, pair: pair, timeSeconds: 0, work: &pairingWork)
        let binding = WitnessContact(coordinateID: 10, tangentLayoutRevision: 1, witness: witness, firstProxyIndex: 0, secondProxyIndex: 1, firstColliderToBody: .identity, secondColliderToBody: .identity, basis: try ContactBasis(frame: identity.frame, contactToQuery: .identity), pair: pair, accepted: history)
        let policy = try ContactResponsePolicy(maximumContacts: 2, maximumColliders: 2, maximumBodies: 2, maximumVelocities: 1, lengthTolerance: 1e-9, normalTolerance: 1e-9, forceScale: 100, lengthScale: 1, powerScale: 100, originalTolerance: 1e-7,
            dynamics: DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky), linearTolerance: LinearTolerance(absoluteResidual: 1e-9, relativeResidual: 1e-10, pivotThreshold: 1e-12), coordinateScales: [1], energyScale: 1, timeScale: 1),
            law: ContactAcceptancePolicy(absoluteEnergyTolerance: 1e-9, absolutePowerTolerance: 1e-9, relativeTolerance: 1e-10, referenceEnergy: 1, referencePower: 1, coneTolerance: 1e-9),
            coneTolerance: ConeTolerance(absolutePrimal: 1e-10, absoluteDual: 1e-10, absoluteComplementarity: 1e-10, absoluteOptimality: 1e-10, relative: 0, primalScale: 1, dualScale: 1), precision: .float64, backend: .referenceCPU, maximumConeIterations: 2000, conePivotThreshold: 1e-12)
        let service: any CoupledContactResponding = ImplicitLinearNormalResponse()
        var outer = try responseNumericalWork(), dynamics = try responseNumericalWork(), cone = try responseNumericalWork(), law = try responseContactWork()
        let input = try ContactResponseInput(system: system, collision: collision, expectedCollisionRevision: 2, expectedModelRevision: 1, contacts: [binding], driveForce: [0], timeStep: 0.1)
        let result = try service.solve(input, policy: policy, responseWork: &outer, dynamicsWork: &dynamics, coneWork: &cone, lawWork: &law)
        let force = 0.1/(0.001+0.01/2)
        try require(abs(result.observations[0].normalForce-force) < 1e-5 && abs(result.endpointVelocity[0]-0.1*force/2) < 1e-6)
        try require(abs(result.effectiveMassInverse[0]-0.5) < 1e-10 && result.originalPhysicalResidual.isAccepted)
        try require(abs(result.observations[0].equivalentImpulseOnB.z-0.1*force) < 1e-6 && result.observations[0].intervalEnd == 0.1)
        try require(abs(result.actualPower-force*result.endpointVelocity[0]) < 1e-6 && result.prescribedPower == 0)
        try require(binding.accepted.sequence == 0 && result.observations[0].lawResponse.trialHistory.sequence == 1)
        let duplicate = WitnessContact(coordinateID: 11, tangentLayoutRevision: 1, witness: witness, firstProxyIndex: 0, secondProxyIndex: 1, firstColliderToBody: .identity, secondColliderToBody: .identity, basis: binding.basis, pair: pair, accepted: history)
        let coupled = try ContactResponseInput(system: system, collision: collision, expectedCollisionRevision: 2, expectedModelRevision: 1, contacts: [binding, duplicate], driveForce: [0], timeStep: 0.1)
        let two = try service.solve(coupled, policy: policy, responseWork: &outer, dynamicsWork: &dynamics, coneWork: &cone, lawWork: &law)
        let each = 0.1/(0.001+0.01)
        try require(two.uniqueCompliantForce && two.effectiveMassRank == nil && two.originalPhysicalResidual.isAccepted)
        try require(two.observations.count == 2 && abs(two.observations[0].normalForce-each) < 1e-5 && abs(two.observations[1].normalForce-each) < 1e-5)
        var staleRejected = false
        do throws(ContactResponseError) {
            let stale = try ContactResponseInput(system: system, collision: collision, expectedCollisionRevision: 3, expectedModelRevision: 1, contacts: [binding], driveForce: [0], timeStep: 0.1)
            _ = try service.solve(stale, policy: policy, responseWork: &outer, dynamicsWork: &dynamics, coneWork: &cone, lawWork: &law)
        } catch { try require(error == .staleCollision); staleRejected = true }
        try require(staleRejected)
    }
    private static func responseNumericalWork() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 1000000, arithmeticOperations: 10000000, iterations: 10000))
    }
    private static func responseContactWork() throws -> ContactWork {
        ContactWork(budget: try ContactBudget(operations: 1000000, scalarStorage: 10000, records: 4))
    }
}
