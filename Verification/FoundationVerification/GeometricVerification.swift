import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func verifyGeometricConstraints() throws {
        let fixture = try FourBarProbeModel()
        let system = try GeometricProbeContext.system(fixture)
        try checkGeometricDerivatives(fixture, system: system)
        try checkGeometricAssembly(fixture, system: system)
        try checkGeometricFailures(fixture, system: system)
        print("Geometric constraint verification passed: actual four-bar geometry, original trigonometric derivatives, manifold assembly and bounded failure.")
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkGeometricDerivatives(_ fixture: FourBarProbeModel, system: GeometricConstraintSystem) throws {
        var q = fixture.model.descriptor.initialState.q
        q[fixture.crankIndex] += 0.03
        q[fixture.couplerIndex] -= 0.02
        let v = [0.4, -0.3, 0.2], a = [0.2, 0.1, -0.4]
        let state = try KinematicState(revision: 1, time: 0.2, q: q, v: v, acceleration: a)
        var work = try GeometricProbeContext.work()
        let evaluator: any HolonomicGeometryProviding = GeometricRelationEvaluator()
        let policy = try GeometricProbeContext.policy().constraints.evaluation
        let sample = try evaluator.evaluate(system, state: state, policy: policy, work: &work)
        let values = fixture.originalClosure(q: q)
        let rates = fixture.originalVelocity(q: q, v: v)
        let accelerations = fixture.originalAcceleration(q: q, v: v, acceleration: a)
        for row in 0..<3 {
            var rate = sample.velocity.drift[row]
            var acceleration = sample.velocity.accelerationBias[row]
            for column in 0..<3 {
                let entry = sample.velocity.rows[row * 3 + column]
                rate += entry * v[column] * 2 / system.layout.scales[column]
                acceleration += entry * a[column] * 4 / system.layout.scales[column]
            }
            try require(abs(sample.values[row] - values[row] / 2) < 1e-10)
            try require(abs(rate / 2 - rates[row] / 2) < 1e-10)
            try require(abs(acceleration / 4 - accelerations[row] / 2) < 1e-10)
        }
        try require(sample.velocity.rowIDs == [1, 2, 3] && work.operations > 0)
        try GeometricOriginalAcceptance.validate(sample, system: system, state: state,
            tolerance: 1e-10, policy: policy, work: &work)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkGeometricAssembly(_ fixture: FourBarProbeModel, system: GeometricConstraintSystem) throws {
        var q = fixture.model.descriptor.initialState.q
        q[fixture.couplerIndex] += 0.025
        let initial = try KinematicState(revision: 1, time: 0, q: q, v: [0, 0, 0], acceleration: [0, 0, 0])
        var work = try GeometricProbeContext.work()
        let assembler: any ManifoldConstraintProjecting = TangentManifoldAssembler()
        let assembled = try assembler.assemble(system, initial: initial, policy: GeometricProbeContext.policy(), work: &work)
        for value in fixture.originalClosure(q: assembled.state.q) { try require(abs(value) < 2e-9) }
        try require(assembled.rank.rank == 2 && assembled.rank.reactionNullity == 1)
        try require(assembled.geometry.velocity.rowIDs == [1, 2, 3])
        try require(assembled.pathCorrection > 0 && assembled.pathCorrection <= 1)
        try require(assembled.state.v == initial.v && assembled.state.time == initial.time)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkGeometricFailures(_ fixture: FourBarProbeModel, system: GeometricConstraintSystem) throws {
        var q = fixture.model.descriptor.initialState.q
        q[fixture.couplerIndex] += 0.025
        let initial = try KinematicState(revision: 1, time: 0, q: q, v: [0, 0, 0], acceleration: [0, 0, 0])
        let assembler: any ManifoldConstraintProjecting = TangentManifoldAssembler()
        var work = try GeometricProbeContext.work(), refused = false
        do { _ = try assembler.assemble(system, initial: initial,
            policy: GeometricProbeContext.policy(limit: 1e-12), work: &work) }
        catch let failure as ManifoldProjectionFailure {
            if case .correctionExceeded = failure.cause { refused = true }
            try require(failure.lastPosition == initial.q && failure.work.operations > 0)
        }
        try require(refused)
        var cancelledWork = try GeometricProbeContext.work(), cancelled = false
        do { _ = try assembler.assemble(system, initial: initial,
            policy: GeometricProbeContext.policy(cancelled: true), work: &cancelledWork) }
        catch let failure as ManifoldProjectionFailure {
            if case .cancelled = failure.cause { cancelled = true }
        }
        try require(cancelled && cancelledWork.operations == 0)
    }
}
