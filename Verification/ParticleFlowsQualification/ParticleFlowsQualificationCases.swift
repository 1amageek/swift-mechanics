import SwiftMechanics

public enum ParticleFlowsQualificationCases {
    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw ParticleFlowsQualificationError.assertion(message) }
    }
    private static func close(_ actual: Double, _ expected: Double, _ message: String,
                              absolute: Double = 2e-9, relative: Double = 2e-10) throws {
        try check(actual.isFinite && expected.isFinite && abs(actual-expected) <= absolute+relative*abs(expected), message)
    }
    private static func close(_ actual: Vector3, _ expected: Vector3, _ message: String) throws {
        try close(actual.x, expected.x, message+" x"); try close(actual.y, expected.y, message+" y")
        try close(actual.z, expected.z, message+" z")
    }
    private static func refuse(_ expected: (ParticleFlowError) -> Bool, _ label: String,
        _ call: () throws(ParticleFlowError) -> Void) throws {
        do { try call() } catch {
            try check(expected(error), label+" wrong typed failure"); return
        }
        throw ParticleFlowsQualificationError.unexpectedSuccess(label)
    }
    public static func kernelNormalization() throws {
        let kernel = WendlandC2Kernel()
        for h in [0.4,1.0] {
            let panels = 2048, step = 2*h/2048
            var integral = 0.0
            for k in 0...panels {
                let r = Double(k)*step, weight = k == 0 || k == panels ? 1.0 : (k%2 == 0 ? 2.0 : 4.0)
                integral += try weight*4*Double.pi*r*r*kernel.value(displacement: Vector3(r,0,0), smoothingLength: h)
            }
            try close(integral*step/3, 1, "three dimensional radial normalization", absolute: 2e-10, relative: 0)
            for q in [0.0,0.4,1.0,1.7,2.0,2.3] {
                let r = q*h
                try close(kernel.value(displacement: Vector3(r,0,0), smoothingLength: h),
                    ParticleFlowsQualificationFixture.kernel(r,h:h), "original kernel")
            }
            let x = try Vector3(0.4*h,0.3*h,0.2*h), epsilon = 1e-6*h
            let actual = try kernel.gradient(displacement: x, smoothingLength: h)
            for axis in 0..<3 {
                let offset = try Vector3(axis == 0 ? epsilon : 0,axis == 1 ? epsilon : 0,axis == 2 ? epsilon : 0)
                let derivative = try (kernel.value(displacement: x.adding(offset), smoothingLength: h)
                    - kernel.value(displacement: x.subtracting(offset), smoothingLength: h))/(2*epsilon)
                try close([actual.x,actual.y,actual.z][axis], derivative, "kernel central derivative", relative: 2e-7)
            }
            try check(kernel.gradient(displacement: .zero, smoothingLength: h) == .zero, "coincident gradient")
            try check(kernel.gradient(displacement: Vector3(2*h,0,0), smoothingLength: h) == .zero, "support gradient")
        }
        try refuse({ $0 == .invalidInput }, "invalid kernel length") { () throws(ParticleFlowError) in
            _ = try kernel.value(displacement: .zero, smoothingLength: 0)
        }
    }
    public static func densityAndEOS() throws {
        let service: any ParticleFlowOperating = ReferenceWeaklyCompressibleSPH(), policy = try ParticleFlowsQualificationFixture.policy()
        let pair = try ParticleFlowsQualificationFixture.pair()
        let a = pair.particles[0], b = pair.particles[1]
        let unequal = try ParticleFlowsQualificationFixture(model: pair.model, particles: [
            FlowParticle(id: a.id, mass: a.mass*1.01, position: a.position, velocity: a.velocity, viscousHeat: 0),
            FlowParticle(id: b.id, mass: b.mass*0.99, position: b.position, velocity: b.velocity, viscousHeat: 0)], time: pair.time)
        for fixture in [try .single(), unequal, try .single(density: 1000*(1+1e-8))] {
            var work = NumericalWork(budget: policy.budget)
            let state = try fixture.prepare(service, policy: policy, work: &work), oracle = try fixture.oracle(fixture.particles, time: fixture.time)
            for i in state.particles.indices {
                try close(state.densities[i], oracle.density[i], "original summation self/pair density")
                try close(state.pressures[i], oracle.pressure[i], "binomial Tait pressure")
                try close(state.barotropicEnergies[i], oracle.energy[i], "positive binomial energy", absolute: 1e-24, relative: 2e-8)
            }
            let diagnostics = try service.evaluate(state, expected: fixture.model.identity, timeStep: nil, policy: policy, work: &work)
            try check(diagnostics.evaluatedTimeStep == nil && diagnostics.maximumTimeStepRatio == 0, "nil step is not admitted dt")
            try close(diagnostics.totalEnergy, oracle.totalEnergy, "original total energy")
        }
    }
    private static func trial(_ fixture: ParticleFlowsQualificationFixture) throws -> ParticleFlowTrial {
        let service: any ParticleFlowOperating = ReferenceWeaklyCompressibleSPH(), policy = try ParticleFlowsQualificationFixture.policy()
        var work = NumericalWork(budget: policy.budget)
        let state = try fixture.prepare(service, policy: policy, work: &work), original = state
        let result = try service.trial(state, expected: fixture.model.identity,
            timeStep: ParticleFlowsQualificationFixture.step, policy: policy, work: &work)
        let expected = try fixture.midpointEndpoint(dt: ParticleFlowsQualificationFixture.step)
        try check(state == original && result.originalRevision == state.revision && result.candidate.revision == state.revision+1, "immutable revision authority")
        try close(result.candidate.time, state.time+ParticleFlowsQualificationFixture.step, "midpoint time")
        for i in state.particles.indices {
            try close(result.candidate.particles[i].position, expected.particles[i].position, "original midpoint position")
            try close(result.candidate.particles[i].velocity, expected.particles[i].velocity, "original midpoint force")
            try close(result.candidate.particles[i].viscousHeat, expected.particles[i].viscousHeat, "original midpoint heat")
        }
        let oracleEnd = try fixture.oracle(expected.particles, time: result.candidate.time)
        try close(result.endpointDiagnostics.totalEnergy, oracleEnd.totalEnergy, "original endpoint energy")
        try check(result.work == work && result.midpointDiagnostics.maximumTimeStepRatio <= 1, "retained admitted work/step")
        return result
    }
    public static func midpointMomentumEnergy() throws {
        let pair = try ParticleFlowsQualificationFixture.pair(), result = try trial(pair)
        try close(result.endpointDiagnostics.momentum, result.initialDiagnostics.momentum, "pair momentum")
        try check(abs(result.energyResidual) <= 1.1e-6, "fixed midpoint energy defect")
        let velocity = try Vector3(0.1,0.02,-0.03), gravity = try Vector3(0,-0.4,0.1)
        let uniform = try ParticleFlowsQualificationFixture.single(velocity: velocity, gravity: gravity), ballistic = try trial(uniform)
        let dt = ParticleFlowsQualificationFixture.step
        try close(ballistic.candidate.particles[0].velocity, velocity.adding(gravity.scaled(by: dt)), "ballistic velocity")
        try close(ballistic.candidate.particles[0].position, uniform.particles[0].position.adding(velocity.scaled(by: dt)).adding(gravity.scaled(by: dt*dt/2)), "ballistic position")
        try close(ballistic.endpointDiagnostics.totalEnergy, ballistic.initialDiagnostics.totalEnergy, "gravity energy")
    }
    public static func viscosityAndHeat() throws {
        let fixture = try ParticleFlowsQualificationFixture.pair(viscosity: 2, moving: true)
        let oracle = try fixture.oracle(fixture.particles, time: fixture.time), result = try trial(fixture)
        try check(oracle.loss > 0, "physical pair positive damping")
        try close(result.initialDiagnostics.viscousLoss, oracle.loss, "Morris pair loss")
        try close(result.initialDiagnostics.viscousHeatPower, oracle.loss, "complete fluid heat power")
        try close(result.initialDiagnostics.pressureInternalPower, oracle.pressurePower, "original pressure power")
        try check(result.candidate.particles.allSatisfy { $0.viscousHeat > 0 }, "both finite particles receive heat")
        let zero = try trial(.pair(viscosity: 0, moving: true))
        try check(zero.initialDiagnostics.viscousLoss == 0 && zero.candidate.particles.allSatisfy { $0.viscousHeat == 0 }, "zero viscosity exact heat")
    }
    public static func prescribedGhostWork() throws {
        let fixture = try ParticleFlowsQualificationFixture.ghost(), result = try trial(fixture)
        let oracle = try fixture.oracle(fixture.particles, time: fixture.time)
        try check(result.initialDiagnostics.boundaryReactions.count == 1, "original ghost reaction")
        let reaction = result.initialDiagnostics.boundaryReactions[0]
        try check(reaction.ghostID == 2, "original ghost identity")
        try close(reaction.force, oracle.reaction, "opposite physical ghost force")
        try close(reaction.prescribedMechanicalPower, oracle.mechanicalPower, "prescribed mechanical power")
        try close(reaction.pressureReservoirPower, oracle.reservoirPower, "fixed density reservoir power")
        let middle = try fixture.midpointEndpoint(dt: ParticleFlowsQualificationFixture.step).middle
        try close(result.boundaryImpulse, middle.reaction.scaled(by: ParticleFlowsQualificationFixture.step), "boundary impulse")
        try close(result.prescribedMechanicalWork, middle.mechanicalPower*ParticleFlowsQualificationFixture.step, "boundary work")
        try close(result.pressureReservoirWork, middle.reservoirPower*ParticleFlowsQualificationFixture.step, "reservoir work")
        try close(result.endpointDiagnostics.totalEnergy-result.initialDiagnostics.totalEnergy,
            result.prescribedMechanicalWork+result.pressureReservoirWork+result.energyResidual, "original full ghost energy balance")
        try check(abs(result.prescribedMechanicalWork) > 0 && abs(result.pressureReservoirWork) > 0, "nonzero independent prescribed work")
    }
    public static func admissionAndTime() throws {
        let service: any ParticleFlowOperating = ReferenceWeaklyCompressibleSPH(), policy = try ParticleFlowsQualificationFixture.policy()
        for (fixture, selector) in [
            (try ParticleFlowsQualificationFixture.single(density: 900), 0),
            (try ParticleFlowsQualificationFixture.single(density: 1200), 1),
            (try ParticleFlowsQualificationFixture.single(velocity: Vector3(4,0,0)), 2)] {
            var work = NumericalWork(budget: policy.budget)
            try refuse({ error in
                switch (selector,error) { case (0,.tensileDomain), (1,.densityDomain), (2,.machDomain): true; default: false }
            }, "physical domain") { () throws(ParticleFlowError) in
                _ = try service.prepare(model: fixture.model, particles: fixture.particles, time: fixture.time, policy: policy, work: &work)
            }
        }
        let fixture = try ParticleFlowsQualificationFixture.pair(), particle = fixture.particles[0]
        var work = NumericalWork(budget: policy.budget)
        try refuse({ $0 == .duplicateIdentity(particle.id) }, "duplicate particle") { () throws(ParticleFlowError) in
            _ = try service.prepare(model: fixture.model, particles: [particle,particle], time: 2, policy: policy, work: &work)
        }
        let coincident = try FlowParticle(id: 3, mass: particle.mass, position: particle.position, velocity: .zero, viscousHeat: 0)
        try refuse({ if case .insufficientSeparation = $0 { true } else { false } }, "coincident distinct particles") { () throws(ParticleFlowError) in
            _ = try service.prepare(model: fixture.model, particles: [particle,coincident], time: 2, policy: policy, work: &work)
        }
        for capability in [ParticleFlowCapability.freeSurfaceWithTensileControl,.dynamicRigidFluidFeedback] {
            let model = ParticleFlowModel(identity: fixture.model.identity, material: fixture.model.material, gravity: .zero, ghosts: [], capability: capability)
            try refuse({ $0 == (capability == .freeSurfaceWithTensileControl ? .unsupportedFreeSurface : .unsupportedDynamicBoundary) }, "selected unsupported capability") { () throws(ParticleFlowError) in
                _ = try service.prepare(model: model, particles: fixture.particles, time: 2, policy: policy, work: &work)
            }
        }
        let state = try fixture.prepare(service, policy: policy, work: &work), original = state
        let stale = try ParticleFlowsQualificationFixture.identity(revision: 2), prefix = work
        try refuse({ $0 == .identityMismatch }, "stale source identity") { () throws(ParticleFlowError) in
            _ = try service.evaluate(state, expected: stale, timeStep: nil, policy: policy, work: &work)
        }
        try check(work == prefix, "identity failure preserves prefix")
        try refuse({ if case .timeStepDomain = $0 { true } else { false } }, "acoustic step refusal") { () throws(ParticleFlowError) in
            _ = try service.trial(state, expected: state.model.identity, timeStep: 1, policy: policy, work: &work)
        }
        try refuse({ $0 == .invalidInput }, "zero trial step") { () throws(ParticleFlowError) in
            _ = try service.trial(state, expected: state.model.identity, timeStep: 0, policy: policy, work: &work)
        }
        try check(state == original, "failed trials leave immutable snapshot")
    }
    public static func exactWorkBounds() throws {
        let fixture = try ParticleFlowsQualificationFixture.single(), service: any ParticleFlowOperating = ReferenceWeaklyCompressibleSPH()
        let metadata = fixture.model.identity.key.utf8.count+fixture.model.identity.source.source.utf8.count+fixture.model.identity.frame.key.utf8.count
        // One particle: original n=1 init308+self64+EOS32+power12+remainder48+ledger120+stability40.
        let operations = metadata+624, storage = metadata+368, iterations = 6
        let budget = try ParticleFlowsQualificationFixture.budget(storage: storage, operations: operations, iterations: iterations)
        let policy = try ParticleFlowsQualificationFixture.policy(budget)
        var work = NumericalWork(budget: budget)
        _ = try fixture.prepare(service, policy: policy, work: &work)
        try check(work.operations == operations && work.iterations == iterations && work.peakScalarStorage == storage, "independent exact prepare logical cost: actual \(work.operations)/\(work.iterations)/\(work.peakScalarStorage), expected \(operations)/\(iterations)/\(storage)")
        for resource in 0..<3 {
            let small = try ParticleFlowsQualificationFixture.budget(storage: storage-(resource == 0 ? 1 : 0),
                operations: operations-(resource == 1 ? 1 : 0), iterations: iterations-(resource == 2 ? 1 : 0))
            let limited = try ParticleFlowsQualificationFixture.policy(small)
            var failed = NumericalWork(budget: small)
            try refuse({ error in
                let expected: NumericalResource = resource == 0 ? .scalarStorage : (resource == 1 ? .arithmeticOperations : .iterations)
                if case .numerical(.resourceLimit(let actual,_)) = error { return actual == expected }; return false
            }, "one less capacity") { () throws(ParticleFlowError) in
                _ = try service.prepare(model: fixture.model, particles: fixture.particles, time: fixture.time, policy: limited, work: &failed)
            }
            try check(failed.operations <= small.arithmeticOperations && failed.iterations <= small.iterations, "failed consumed prefix remains bounded")
        }
        let large = try ParticleFlowsQualificationFixture.policy()
        var cumulative = NumericalWork(budget: large.budget)
        let state = try fixture.prepare(service, policy: large, work: &cumulative)
        _ = try service.evaluate(state, expected: state.model.identity, timeStep: nil, policy: large, work: &cumulative)
        try check(cumulative.operations == 2*operations+12 && cumulative.iterations == 2*iterations, "evaluate cumulative work not reset")
        let result = try service.trial(state, expected: state.model.identity, timeStep: ParticleFlowsQualificationFixture.step, policy: large, work: &cumulative)
        try check(cumulative.operations == 2*operations+12+metadata+2061 && cumulative.iterations == 28 && result.work == cumulative, "trial cumulative stage costs")
    }
    public static func nativeCancellation() async throws {
        let cancelled = Task { () throws -> NumericalWork in
            withUnsafeCurrentTask { current in current?.cancel() }
            let fixture = try ParticleFlowsQualificationFixture.single(), policy = try ParticleFlowsQualificationFixture.policy()
            var work = NumericalWork(budget: policy.budget)
            let service: any ParticleFlowOperating = ReferenceWeaklyCompressibleSPH()
            try refuse({ $0 == .numerical(.cancelled) }, "actual Task cancellation") { () throws(ParticleFlowError) in
                _ = try service.prepare(model: fixture.model, particles: fixture.particles, time: fixture.time, policy: policy, work: &work)
            }
            return work
        }
        let work = try await cancelled.value
        try check(work.operations == 0 && work.iterations == 0 && work.peakScalarStorage == 0, "pre-cancelled call publishes nothing and consumes no prefix")
    }
}
