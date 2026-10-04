import SwiftMechanics

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    static func verifyConstrainedNormalImpact() throws {
        try verifyGearedStrikerImpact(restitution: 1)
        try verifyGearedStrikerImpact(restitution: 0)
        try verifyImpactAssemblySourceRefusal()
        print("Constrained impact passed: actual geared striker, simultaneous impulses, original momentum/rebound/energy and source refusal.")
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyGearedStrikerImpact(restitution: Double) throws {
        let context = try ConstrainedImpactProbeContext(restitution: restitution)
        let cancellation = HybridCancellation()
        let admission = context.makeAdmission(cancellation: cancellation)
        var work = context.makeWork(), loads = try context.makeLoadWork(cancellation: cancellation)
        var contact = context.makeContactWork()
        let prepared = try context.prepare(admission: admission, loadWork: &loads, work: &work, cancellation: cancellation)
        try require(prepared.impact.normalRows == [-1, 0, 1] && prepared.retainedRows == [1, 1, 0])
        try require(prepared.impact.system.massMatrix == [2, 0, 0, 0, 2, 0, 0, 0, 2])
        let result = try context.solve(prepared, work: &work, contactWork: &contact, cancellation: cancellation)
        try require(result.velocity.count == 3 && result.retainedImpulses.count == 1)
        try require(result.retainedGeneralizedImpulse.count == 3)
        let impulse = 4 * (1 + restitution) / 3
        let expectedVelocity = [-impulse / 4, impulse / 4, -1 + impulse / 2]
        let contactRow = [-1.0, 0, 1], retainedImpulse = [impulse / 2, impulse / 2, 0]
        var energy = 0.0
        for index in 0..<3 {
            let velocity = result.velocity[index]
            try require(abs(velocity - expectedVelocity[index]) < 1e-9)
            let originalMomentumChange = 2 * (velocity - context.input.physical.state.v[index])
            try require(abs(originalMomentumChange - contactRow[index] * impulse - retainedImpulse[index]) < 1e-9)
            try require(abs(result.retainedGeneralizedImpulse[index] - retainedImpulse[index]) < 1e-9)
            energy += velocity * velocity
        }
        try require(abs(result.velocity[0] + result.velocity[1]) < 1e-9)
        try require(abs(-result.velocity[0] + result.velocity[2] - restitution) < 1e-9)
        try require(abs(result.contactImpulse - impulse) < 1e-9)
        try require(abs(result.retainedImpulses[0] - impulse / 2) < 1e-9)
        try require(abs(result.effectiveInverseMass - 0.75) < 1e-9)
        let loss = 2 * (1 - restitution * restitution) / 3
        try require(abs(result.kineticEnergyBefore - 1) < 1e-9 && abs(result.kineticEnergyAfter - energy) < 1e-9)
        try require(abs(1 - energy - loss) < 1e-9 && abs(result.predictedLostEnergy - loss) < 1e-9)
        try require(result.source === prepared && result.eventID == 41 && result.time == 0.25)
        try require(result.normalizedMomentumResidual < 1e-9 && result.normalizedConstraintResidual < 1e-9)
        try require(result.lawResidual < 1e-9 && result.energyResidual < 1e-9)
        try require(work.operations > 0 && loads.consumed > 0 && contact.operations > 0)
        try require(context.source.constraintConstructionWork.operations > 0)
        try require(context.collisionConstructionWork.operations > 0 && context.pairingConstructionWork.operations > 0)
        try verifyImpactInputPreserved(context)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyImpactAssemblySourceRefusal() throws {
        let context = try ConstrainedImpactProbeContext(restitution: 1)
        let model = context.source.model, original = context.input.physical.state
        var q = original.q
        q[context.source.firstRotorCoordinateIndex] = 0.1
        q[context.source.secondRotorCoordinateIndex] = -0.1
        let alternateState = try model.makeState(KinematicState(revision: original.revision, time: original.time,
            q: q, v: original.v, acceleration: original.acceleration))
        let alternateInput = try RigidDynamicsInput(snapshot: model.evaluate(alternateState), velocity: original.v,
            inertias: context.input.inertias, gravity: nil)
        let preparer: any ConstrainedImpactPreparing = ReferenceConstrainedImpactPreparer(
            equations: SubstitutedImpactEquation(input: alternateInput))
        let cancellation = HybridCancellation(), admission = context.makeAdmission(cancellation: cancellation)
        var work = context.makeWork(), loads = try context.makeLoadWork(cancellation: cancellation)
        var refused = false
        do throws(ConstrainedImpactError) {
            _ = try preparer.prepare(input: context.input, constraints: context.source.constraints, policy: context.policy,
                admission: admission, loadWork: &loads, work: &work, cancellation: cancellation)
        } catch {
            guard case .sourceMismatch = error.reason, !error.failedSupplierWorkUnavailable else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            refused = true
        }
        try require(refused && work.operations > 0 && loads.consumed > 0)
        try verifyImpactInputPreserved(context)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyImpactInputPreserved(_ context: ConstrainedImpactProbeContext) throws {
        try require(context.input.physical.state.q == [0, 0, 0.5])
        try require(context.input.physical.state.v == [0, 0, -1])
        try require(context.input.physical.state.time == 0.25)
        try require(context.source.model.descriptor.initialState == context.input.physical.state)
    }

    private struct SubstitutedImpactEquation: RigidEquationComputing {
        let input: RigidDynamicsInput
        func assemble(_ ignored: RigidDynamicsInput, admission: DynamicsAdmission,
            loadWork: inout LoadWork, work: inout NumericalWork) throws(DynamicsError) -> RigidDynamicsSystem {
            try RigidEquationKernel().assemble(input, admission: admission, loadWork: &loadWork, work: &work)
        }
        func originalInertialForce(_ system: RigidDynamicsSystem, acceleration: [Double], includeBias: Bool,
            into output: inout [Double], work: inout NumericalWork) throws(DynamicsError) {
            try RigidEquationKernel().originalInertialForce(system, acceleration: acceleration,
                includeBias: includeBias, into: &output, work: &work)
        }
        func inertialWrench(_ system: RigidDynamicsSystem, body: EntityID, acceleration: [Double],
            referencePointWorld: Vector3, work: inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence {
            try RigidEquationKernel().inertialWrench(system, body: body, acceleration: acceleration,
                referencePointWorld: referencePointWorld, work: &work)
        }
        func energy(_ system: RigidDynamicsSystem, acceleration: [Double], angularMomentumReference: Vector3,
            requireComplete: Bool, work: inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy {
            try RigidEquationKernel().energy(system, acceleration: acceleration,
                angularMomentumReference: angularMomentumReference, requireComplete: requireComplete, work: &work)
        }
    }
}
