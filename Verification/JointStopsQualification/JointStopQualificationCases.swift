import SwiftMechanics

public enum JointStopQualificationCases {
    private static func require(_ condition: Bool, _ message: String) throws(JointStopQualificationError) {
        guard condition else { throw .assertion(message) }
    }
    private static func close(_ actual: Double, _ expected: Double, _ message: String) throws(JointStopQualificationError) {
        try require(actual.isFinite && expected.isFinite && abs(actual - expected) <= 1e-8 * max(1, abs(expected)), message)
    }
    private static func close(_ actual: [Double], _ expected: [Double], _ message: String) throws(JointStopQualificationError) {
        try require(actual.count == expected.count, message + " shape")
        for i in expected.indices { try close(actual[i], expected[i], message) }
    }
    private static func expect(_ message: String, _ predicate: (JointStopFailure) -> Bool,
                               _ operation: () throws(JointStopFailure) -> Void) throws(JointStopQualificationError) {
        do throws(JointStopFailure) { try operation() }
        catch {
            guard predicate(error) else { throw .unexpectedFailure(error) }
            return
        }
        throw .unexpectedSuccess(message)
    }

    private static func execute(_ fixture: JointStopQualificationFixture, _ input: JointStopInput,
                                side: JointStopSide) throws -> JointStopImpactResult {
        let contributor: any JointStopContributing = ReferenceJointStopContributor()
        let policy = try fixture.policy()
        var work = try JointStopQualificationFixture.work()
        var loads = try JointStopQualificationFixture.loadWork(), contacts = try JointStopQualificationFixture.contactWork()
        let prepared = try contributor.prepare(input, policy: policy, work: &work)
        try require(prepared.layout.positions.start == 0 && prepared.layout.velocities.start == 0,
                    "independent fixture target must occupy the original first scalar slot")
        try close(prepared.gaps.lowerGap, input.state.state.q[0] - input.definition.lower, "original signed lower gap")
        try close(prepared.gaps.upperGap, input.definition.upper - input.state.state.q[0], "original signed upper gap")
        try close(prepared.gaps.lowerGapRate, input.state.state.v[0], "original lower coordinate rate")
        try close(prepared.gaps.upperGapRate, -input.state.state.v[0], "original upper coordinate rate")
        let result = try contributor.impact(prepared, side: side, policy: policy, work: &work, loadWork: &loads, contactWork: &contacts)
        try require(result.diagnostics.numericalWork == work && work.operations > 0 && contacts.operations > 0,
                    "caller-owned cumulative work must survive actual impact")
        try require(result.stateAfter.state.q == input.state.state.q && result.stateAfter.state.time == 3 &&
                    result.stateAfter.stamp == input.model.stamp && result.sourceAfter.state == result.stateAfter,
                    "instantaneous jump must preserve original source position/time")
        try close(result.stateAfter.state.acceleration, [Double](repeating: 0, count: fixture.count), "instantaneous acceleration convention")
        try require(result.normalImpulseNewtonSeconds > 0 && result.coordinateImpulse > 0, "positive unilateral impulse")
        try close(result.diagnostics.normalRateResidualMetersPerSecond, 0, "original normal-rate residual")
        try close(result.diagnostics.normalizedMomentumResidual, 0, "original momentum residual")
        try close(result.diagnostics.energyResidualJoules, 0, "original energy residual")
        try close(result.diagnostics.workResidualJoules, 0, "original work residual")
        try independentlyRecompute(fixture, input, result, policy: policy)
        return result
    }

    private static func independentlyRecompute(_ fixture: JointStopQualificationFixture, _ input: JointStopInput,
                                               _ result: JointStopImpactResult, policy: JointStopPolicy) throws {
        var work = try JointStopQualificationFixture.work(), loads = try JointStopQualificationFixture.loadWork()
        let sourcePreparer: any ObservationSourcePreparing = ReferenceObservationSourcePreparer()
        let sourceBefore = try sourcePreparer.prepare(model: fixture.model, state: input.state, solved: nil, policy: policy.observations, work: &work)
        let rebuilt = try fixture.model.makeState(result.stateAfter.state)
        let sourceAfter = try sourcePreparer.prepare(model: fixture.model, state: rebuilt, solved: nil, policy: policy.observations, work: &work)
        let observer: any KinematicObserving = ReferenceKinematicObserver()
        let encoder = try observer.encoder(source: sourceAfter, joint: fixture.joint, policy: policy.observations, work: &work)
        let unit = input.definition.coordinateUnit
        let rateUnit = PhysicalDimension(length: unit.length, time: -1, angle: unit.angle)
        try require(encoder.positions == result.encoderAfter.positions && encoder.velocities == result.encoderAfter.velocities &&
                    encoder.positionUnits == [unit] && encoder.coordinateRateUnits == [rateUnit] &&
                    encoder.velocityUnits == [rateUnit] && encoder.accelerationAuthority == .suppliedState,
                    "fresh qualified encoder must match returned post source and SI coordinate")
        let sign = result.side == .lower ? 1.0 : -1.0
        try close(sign * input.definition.metersPerCoordinateUnit * encoder.coordinateRates[0],
                  result.diagnostics.normalSpeedAfterMetersPerSecond, "fresh original signed normal rate")
        let beforeInput = try RigidDynamicsInput(snapshot: sourceBefore.snapshot, velocity: input.state.state.v,
                                                inertias: fixture.inertias, gravity: nil)
        let afterInput = try RigidDynamicsInput(snapshot: sourceAfter.snapshot, velocity: rebuilt.state.v,
                                               inertias: fixture.inertias, gravity: nil)
        let kernel = RigidEquationKernel()
        let before = try kernel.assemble(PhysicalRigidDynamicsInput(spatial: beforeInput), admission: policy.admission, loadWork: &loads, work: &work)
        let after = try kernel.assemble(PhysicalRigidDynamicsInput(spatial: afterInput), admission: policy.admission, loadWork: &loads, work: &work)
        var momentum = [Double](repeating: 0, count: fixture.count)
        try kernel.originalInertialForce(before, acceleration: result.velocityJump, includeBias: false, into: &momentum, work: &work)
        try close(momentum, result.generalizedImpulse, "independent original Newton/Euler generalized momentum")
        let zero = [Double](repeating: 0, count: fixture.count)
        let energyBefore = try kernel.energy(before, acceleration: zero, angularMomentumReference: .zero, requireComplete: true, work: &work)
        let energyAfter = try kernel.energy(after, acceleration: zero, angularMomentumReference: .zero, requireComplete: true, work: &work)
        try close(energyBefore.kineticEnergy, result.energyBefore.kineticEnergy, "independent original pre kinetic energy")
        try close(energyAfter.kineticEnergy, result.energyAfter.kineticEnergy, "independent original post kinetic energy")
        var impulseWork = 0.0
        for i in momentum.indices { impulseWork += result.generalizedImpulse[i] * (input.state.state.v[i] + rebuilt.state.v[i]) / 2 }
        try close(impulseWork, energyAfter.kineticEnergy - energyBefore.kineticEnergy, "independent impulse work equals original kinetic change")
        try close(impulseWork, result.diagnostics.normalImpulseWorkJoules, "independent generalized/normal impulse virtual work")
    }

    public static func coupledLowerBoundary() throws {
        let fixture = try JointStopQualificationFixture(specification: .prismatic(axis: .unitX), serial: true)
        let input = try fixture.input(position: [0, 0], velocity: [-2, 1])
        let result = try execute(fixture, input, side: .lower)
        try close(result.physicalBefore.massMatrix, [5, 3, 3, 3], "independent serial slider mass matrix")
        try close(result.stateAfter.state.v, [1, -2], "coupled full velocity response")
        try close(result.velocityJump, [3, -3], "coupled jump")
        try close(result.generalizedImpulse, [6, 0], "lower compressive generalized impulse")
        try close(result.normalImpulseNewtonSeconds, 6, "lower SI normal impulse")
        try close(result.diagnostics.effectiveInverseMassPerKilogram, 0.5, "coupled effective inverse mass")
        try close(result.energyBefore.kineticEnergy, 5.5, "analytic original pre energy")
        try close(result.energyAfter.kineticEnergy, 2.5, "analytic original post energy")
        try close(result.diagnostics.normalLossJoules, 3, "analytic normal kinetic loss")
        try close(result.diagnostics.generalizedImpulseWorkJoules, -3, "analytic impulse work")
        try close(result.energyAfter.linearMomentum.x - result.energyBefore.linearMomentum.x, 6, "original body linear momentum difference")
        try require(result.coordinateImpulseUnit == PhysicalDimension(length: 1, mass: 1, time: -1), "prismatic conjugate impulse SI unit")
    }

    public static func upperElasticAndLowerPlastic() throws {
        let fixture = try JointStopQualificationFixture(specification: .prismatic(axis: .unitX))
        let upper = try execute(fixture, fixture.input(position: [0], velocity: [2], lower: -2, upper: 0, restitution: 1), side: .upper)
        try close(upper.stateAfter.state.v, [-2], "upper elastic post velocity")
        try close(upper.generalizedImpulse, [-8], "upper signed impulse")
        try close(upper.diagnostics.normalLossJoules, 0, "elastic normal loss")
        try close(upper.energyBefore.kineticEnergy, 4, "elastic pre kinetic energy")
        try close(upper.energyAfter.kineticEnergy, 4, "elastic post kinetic energy")
        let lower = try execute(fixture, fixture.input(position: [0], velocity: [-2], restitution: 0), side: .lower)
        try close(lower.stateAfter.state.v, [0], "lower plastic post velocity")
        try close(lower.generalizedImpulse, [4], "lower plastic impulse")
        try close(lower.diagnostics.normalLossJoules, 4, "plastic normal loss")
        try close(lower.energyAfter.kineticEnergy, 0, "plastic post kinetic energy")
    }

    public static func rotaryMetricAndThreshold() throws {
        let fixture = try JointStopQualificationFixture(specification: .revolute(axis: .unitZ))
        let above = try execute(fixture, fixture.input(position: [0], velocity: [-4], unit: .angle,
            metric: 0.25, restitution: 0.5, threshold: 0.8), side: .lower)
        try close(above.physicalBefore.massMatrix, [3], "analytic COM-shifted hinge inertia")
        try close(above.diagnostics.normalSpeedBeforeMetersPerSecond, -1, "explicit radians to normal meters per second")
        try close(above.diagnostics.effectiveInverseMassPerKilogram, 1.0 / 48, "metric-scaled inverse mass")
        try close(above.stateAfter.state.v, [2], "rotary post radians per second")
        try close(above.normalImpulseNewtonSeconds, 72, "rotary metric normal impulse")
        try close(above.coordinateImpulse, 18, "rotary coordinate-conjugate impulse")
        try close(above.energyBefore.kineticEnergy, 24, "rotary pre kinetic energy")
        try close(above.energyAfter.kineticEnergy, 6, "rotary post kinetic energy")
        try close(above.energyAfter.angularMomentum.z - above.energyBefore.angularMomentum.z, 18, "original hinge angular momentum difference")
        try require(above.coordinateImpulseUnit == PhysicalDimension(length: 2, mass: 1, time: -1, angle: -1), "rotary impulse unit retains radians")
        let below = try execute(fixture, fixture.input(position: [0], velocity: [-4], unit: .angle,
            metric: 0.1, restitution: 0.5, threshold: 0.8), side: .lower)
        try close(below.diagnostics.normalSpeedBeforeMetersPerSecond, -0.4, "threshold consumes SI m/s rather than raw rad/s")
        try close(below.stateAfter.state.v, [0], "subthreshold plastic post angular rate")
        try close(below.coordinateImpulse, 12, "subthreshold coordinate impulse")
        try close(below.diagnostics.normalLossJoules, 24, "subthreshold actual kinetic loss")
    }

    public static func signedBoundaryRefusals() throws {
        let fixture = try JointStopQualificationFixture(specification: .prismatic(axis: .unitX))
        let policy = try fixture.policy(), contributor: any JointStopContributing = ReferenceJointStopContributor()
        for (q, v, lower, upper, failure) in [(0.25, -2.0, 0.0, 2.0, 0), (0.0, 2.0, 0.0, 2.0, 1), (0.0, -2.0, 0.0, 0.5e-9, 2)] {
            let input = try fixture.input(position: [q], velocity: [v], lower: lower, upper: upper)
            var work = try JointStopQualificationFixture.work(), loads = try JointStopQualificationFixture.loadWork()
            var contacts = try JointStopQualificationFixture.contactWork()
            let prepared = try contributor.prepare(input, policy: policy, work: &work)
            try expect("boundary law refusal", { error in
                switch (failure, error.cause) { case (0, .nonboundary), (1, .nonapproaching), (2, .ambiguousBoundary): true; default: false }
            }) { () throws(JointStopFailure) in
                _ = try contributor.impact(prepared, side: .lower, policy: policy, work: &work, loadWork: &loads, contactWork: &contacts)
            }
            try require(work.operations > 0, "boundary refusal retains consumed preparation work")
        }
    }

    public static func sourceUnitAndUnsupportedRefusals() throws {
        let fixture = try JointStopQualificationFixture(specification: .prismatic(axis: .unitX))
        let contributor: any JointStopContributing = ReferenceJointStopContributor(), policy = try fixture.policy()
        let stamp = ModelStamp(identity: fixture.model.stamp.identity, revision: 2)
        let stale = try fixture.input(position: [0], velocity: [-2], stamp: stamp)
        let wrongUnit = try fixture.input(position: [0], velocity: [-2], unit: .angle)
        let wrongMetric = try fixture.input(position: [0], velocity: [-2], metric: 0.5)
        for (input, isStale) in [(stale, true), (wrongUnit, false), (wrongMetric, false)] {
            var work = try JointStopQualificationFixture.work()
            try expect("source or SI refusal", { error in
                switch (isStale, error.cause) { case (true, .staleSource), (false, .unitMismatch): true; default: false }
            }) { () throws(JointStopFailure) in _ = try contributor.prepare(input, policy: policy, work: &work) }
        }
        let periodic = try fixture.input(position: [0], velocity: [-2], wrap: .periodic(period: 2))
        let continuous = try fixture.input(position: [0], velocity: [-2], continuousLoss: true)
        let screwFixture = try JointStopQualificationFixture(specification: .screw(axis: .unitZ, pitchMetersPerRadian: 0.1))
        let screw = try screwFixture.input(position: [0], velocity: [-2], unit: .angle)
        for input in [periodic, continuous, screw] {
            var work = try JointStopQualificationFixture.work()
            try expect("unsupported physical domain", { if case .unsupportedDomain = $0.cause { true } else { false } }) {
                () throws(JointStopFailure) in _ = try contributor.prepare(input, policy: policy, work: &work)
            }
        }
    }

    public static func boundedWorkAndCancellation() throws {
        let fixture = try JointStopQualificationFixture(specification: .prismatic(axis: .unitX))
        let input = try fixture.input(position: [0], velocity: [-2]), policy = try fixture.policy()
        let contributor: any JointStopContributing = ReferenceJointStopContributor()
        for (operations, storage) in [(1000, 1_000_000), (20_000_000, 1)] {
            var work = try JointStopQualificationFixture.work(operations: operations, storage: storage)
            try expect("bounded work refusal", { if case .numerical(.resourceLimit) = $0.cause { true } else { false } }) {
                () throws(JointStopFailure) in _ = try contributor.prepare(input, policy: policy, work: &work)
            }
            try require(work.operations > 0 && work.operations <= operations, "failed budget preserves bounded consumed prefix")
        }
        let cancelled = try fixture.policy(cancelled: true)
        var work = try JointStopQualificationFixture.work()
        try expect("explicit cancellation", { if case .cancelled = $0.cause { true } else { false } }) {
            () throws(JointStopFailure) in _ = try contributor.prepare(input, policy: cancelled, work: &work)
        }
        try require(work.operations == 0, "pre-admission cancellation consumes no supplier work")
    }

    public static func supplierFailureAndLedger() throws {
        let fixture = try JointStopQualificationFixture(specification: .prismatic(axis: .unitX))
        let input = try fixture.input(position: [0], velocity: [-2]), policy = try fixture.policy()
        var refusalWork = 0, resetWork = 0
        for reset in [false, true] {
            let contributor: any JointStopContributing = ReferenceJointStopContributor(mass:
                JointStopQualificationRefusingMass(mode: reset ? .resetLedger : .refuseAfterWork))
            var work = try JointStopQualificationFixture.work(), loads = try JointStopQualificationFixture.loadWork()
            var contacts = try JointStopQualificationFixture.contactWork()
            let prepared = try contributor.prepare(input, policy: policy, work: &work)
            try expect("mass supplier refusal", { error in
                if reset { if case .invalidSupplierLedger = error.cause { return error.failedSupplierWorkUnavailable }; return false }
                if case .dynamics(.cancelled) = error.cause { return !error.failedSupplierWorkUnavailable }; return false
            }) { () throws(JointStopFailure) in
                _ = try contributor.impact(prepared, side: .lower, policy: policy, work: &work, loadWork: &loads, contactWork: &contacts)
            }
            try require(contacts.operations == 0, "failed original mass prerequisite never reaches restitution")
            if reset { resetWork = work.operations } else { refusalWork = work.operations }
        }
        try require(refusalWork == resetWork + 13 && resetWork > 0, "valid failed supplier work is charged; reset preserves only the known seed")
    }

    public static func actualTaskCancellation(input: JointStopInput, policy: JointStopPolicy) throws {
        var work = try JointStopQualificationFixture.work()
        let contributor: any JointStopContributing = ReferenceJointStopContributor()
        try expect("actual Task cancellation", { if case .cancelled = $0.cause { true } else { false } }) {
            () throws(JointStopFailure) in _ = try contributor.prepare(input, policy: policy, work: &work)
        }
    }
}
