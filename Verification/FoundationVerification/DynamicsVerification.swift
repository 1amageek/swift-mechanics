import SwiftMechanics

extension FoundationVerification {
    static func verifyDynamics() throws {
        let world = try EntityID(kind: .frame, key: "dynamics-world")
        let rootID = try EntityID(kind: .body, key: "dynamics-root")
        let childID = try EntityID(kind: .body, key: "dynamics-child")
        let rootFrame = try EntityID(kind: .frame, key: "dynamics-root-frame")
        let childFrame = try EntityID(kind: .frame, key: "dynamics-child-frame")
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let rootMass = try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .identity, policy: inertiaPolicy)
        let childMass = try MassProperties3D(mass: 2, centerOfMass: .unitX, inertiaAtCenter: .identity, policy: inertiaPolicy)
        let bodies = [
            KinematicBody(body: try BodyRecord3D(id: rootID, frame: rootFrame, mode: .dynamic, bodyToWorld: .identity,
                representations: BodyRepresentations(), inertia: InertialRepresentation3D(properties: rootMass,
                    provenance: SourceProvenance(source: "dynamics-probe", revision: 1), quality: .exact))),
            KinematicBody(body: try BodyRecord3D(id: childID, frame: childFrame, mode: .dynamic, bodyToWorld: .identity,
                representations: BodyRepresentations(), inertia: InertialRepresentation3D(properties: childMass,
                    provenance: SourceProvenance(source: "dynamics-probe", revision: 1), quality: .exact)))
        ]
        let hinge = try JointRecord(id: EntityID(kind: .joint, key: "dynamics-hinge"), parentBody: rootID, childBody: childID,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "dynamics-anchor-a"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "dynamics-anchor-b"), placement: .fixed(.identity)),
            manifold: JointManifold(.revolute(axis: .unitZ)))
        let tree = try KinematicTree(bodies: bodies, joints: [hinge], root: rootID, rootBase: .fixed, worldFrame: world,
            revision: 1, capacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12))
        let motion: any TreeKinematicsComputing = TreeKinematicsEvaluator()
        let snapshot = try motion.evaluate(tree, state: KinematicState(revision: 1, time: 0, q: [0], v: [2], acceleration: [99]),
            policy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1))
        let inertias = [try RigidBodyInertia(body: rootID, frame: rootFrame, properties: rootMass),
                        try RigidBodyInertia(body: childID, frame: childFrame, properties: childMass)]
        var loadWork = LoadWork(budget: try LoadBudget(maximumWork: 100, maximumScalars: 0))
        let passive: any ScalarLoadEvaluating = ScalarLoadEvaluator()
        let response = try passive.evaluate(PolynomialSpringDamper(coordinateKind: .rotation, restCoordinate: 0,
            quadraticStiffness: 2, linearDamping: 3, maximumDisplacement: 1, maximumRate: 3),
            coordinate: 0, rate: 2, work: &loadWork)
        let load = try GeneralizedForceContribution(values: [response.total()], channel: .applied,
            potentialEnergy: response.potentialEnergy, dissipatedPower: response.dissipatedPower)
        let gravity = try AffineGravity(frame: world, accelerationAtOrigin: Vector3(0, -10, 0))
        let input = try RigidDynamicsInput(snapshot: snapshot, velocity: [2], inertias: inertias, gravity: gravity,
            generalizedForces: [load])
        let admission = DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 2, maximumVelocities: 1,
            maximumBodyWrenches: 0, maximumGeneralizedContributions: 1), angularVelocityTolerance: tolerance,
            linearVelocityTolerance: tolerance)
        var work = NumericalWork(budget: try NumericalBudget(scalarStorage: 10000, arithmeticOperations: 100000, iterations: 10))
        let equations: any RigidEquationComputing = RigidEquationKernel()
        let system = try equations.assemble(input, admission: admission, loadWork: &loadWork, work: &work)
        try require(abs(system.massMatrix[0] - 3) < 1e-10 && abs(system.inertialBias[0]) < 1e-10)
        try require(abs(system.forces.gravity[0] + 20) < 1e-10 && abs(system.forces.applied[0] + 6) < 1e-10)
        try require(system.assemblyLoadWork.consumed == 3 && abs(system.forces.actualPower + 52) < 1e-10)
        let policy = try DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            linearTolerance: LinearTolerance<Double>(absoluteResidual: 1e-9, relativeResidual: 1e-10, pivotThreshold: 1e-12),
            coordinateScales: [0.5], energyScale: 2, timeScale: 0.7)
        let solver: any RigidDynamicsSolving = DenseRigidDynamics()
        let forward = try solver.forward(system, driveForce: [0], policy: policy, work: &work)
        try require(abs(forward.acceleration[0] + 26.0 / 3) < 1e-9 && forward.originalPhysicalResidual.isAccepted)
        let inverse = try solver.inverse(system, acceleration: forward.acceleration, policy: policy, work: &work)
        try require(abs(inverse.driveForce[0]) < 1e-9 && inverse.originalPhysicalResidual.isAccepted)
        let massOnly = try solver.inverseMassProduct(system, rightHandSide: [6], policy: policy, work: &work)
        try require(abs(massOnly.acceleration[0] - 2) < 1e-9 && massOnly.originalPhysicalResidual.equation == .massOnly)
        let mixed = try solver.mixed(system, partition: [.prescribedAcceleration(0)], policy: policy, work: &work)
        try require(mixed.acceleration == [0] && abs(mixed.driveForce[0] - 26) < 1e-9 && mixed.linearDiagnostics == nil)
        let energy = try equations.energy(system, acceleration: forward.acceleration, angularMomentumReference: .zero,
            requireComplete: true, work: &work)
        try require(abs(energy.kineticEnergy - 6) < 1e-10 && energy.potentialEnergy == 0 && energy.dissipatedPower == 12)
        try require(abs(energy.kineticEnergyRate + 52) < 1e-9 && abs(energy.kineticEnergyRate + 40 + 12) < 1e-9)
        var mismatchRejected = false
        do throws(DynamicsError) {
            _ = try equations.assemble(RigidDynamicsInput(snapshot: snapshot, velocity: [3], inertias: inertias, gravity: gravity),
                admission: admission, loadWork: &loadWork, work: &work)
        } catch {
            try require(error == .velocityMismatch)
            mismatchRejected = true
        }
        let nonuniform = try AffineGravity(frame: world, accelerationAtOrigin: .zero, gradient: .identity)
        var nonuniformRejected = false
        do throws(DynamicsError) {
            _ = try equations.assemble(RigidDynamicsInput(snapshot: snapshot, velocity: [2], inertias: inertias,
                gravity: nonuniform),
                admission: admission, loadWork: &loadWork, work: &work)
        } catch {
            try require(error == .unsupportedDomain)
            nonuniformRejected = true
        }
        try require(mismatchRejected && nonuniformRejected)
    }
}
