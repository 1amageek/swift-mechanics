import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public enum ImplicitMethodsQualificationCases {
    public static func eulerPhysicalEndpointAndEnergy() throws(ImplicitMethodsQualificationError) {
        try ImplicitMethodsQualificationFixtures.translated {
            let physics = try ImplicitQualificationPhysics(), model = try ImplicitMethodsQualificationFixtures.model(physics)
            let equation = try ImplicitQualificationODE(model: model, physics: physics)
            let session = try ImplicitMethodsQualificationFixtures.session(model, physics: physics)
            defer { _ = session.shutdown() }
            let initial = session.snapshot(), h = 0.2
            let result = try ReferenceImplicitEulerIntegrator().step(session, model: model, equations: equation, to: h,
                policy: ImplicitMethodsQualificationFixtures.eulerPolicy())
            let expected = ImplicitMethodsQualificationOracle.euler(physics, q: 0.25, v: -0.2, h: h)
            try endpoint(result, expected: expected, model: model, time: h)
            let qResidual = result.endpoint.point[0]-0.25-h*result.endpoint.point[1]
            let vResidual = result.endpoint.point[1]+0.2-h*physics.acceleration(q: result.endpoint.point[0], v: result.endpoint.point[1])
            let originalNorm = max(abs(qResidual)/(0.25+0.1*0.25), abs(vResidual)/(0.5+0.1*0.2))
            try ImplicitMethodsQualificationFixtures.near(result.endpoint.originalResidual.infinityNorm, originalNorm,
                "Independent original scaled backward Euler residual witness.")
            let before = ImplicitMethodsQualificationOracle.energy(physics, q: 0.25, v: -0.2)
            let after = ImplicitMethodsQualificationOracle.energy(physics, q: expected.q, v: expected.v)
            let decrement = -h*physics.damping*expected.v*expected.v
                - physics.mass*(expected.v+0.2)*(expected.v+0.2)/2-physics.stiffness*(expected.q-0.25)*(expected.q-0.25)/2
            try ImplicitMethodsQualificationFixtures.near(after-before, decrement, "Independent backward Euler physical dissipation identity.")
            try ImplicitMethodsQualificationFixtures.require(after < before, "Actual implicit energy decay.")
            try ImplicitMethodsQualificationFixtures.require(initial.checkpoint.random.draws == 0 && result.accepted.checkpoint.random.draws == 1
                && result.accepted.checkpoint.contributors[0].bytes == [1] && result.accepted.checkpoint.acceptedSteps == 1,
                "One actual prepare/random/contributor publication.")
            try ImplicitMethodsQualificationFixtures.require(session.profile().committedTransactions == 1
                && result.accepted == session.snapshot(), "Actual authoritative Runtime publication.")
            let stiff = try ImplicitQualificationPhysics(mass: 2, stiffness: 0, damping: 200, constantLoad: 0)
            let stiffModel = try ImplicitMethodsQualificationFixtures.model(stiff)
            let stiffSession = try ImplicitMethodsQualificationFixtures.session(stiffModel, physics: stiff, q: 0, v: 1)
            defer { _ = stiffSession.shutdown() }
            let stiffResult = try ReferenceImplicitEulerIntegrator().step(stiffSession, model: stiffModel,
                equations: ImplicitQualificationODE(model: stiffModel, physics: stiff), to: 0.2,
                policy: ImplicitMethodsQualificationFixtures.eulerPolicy())
            try endpoint(stiffResult, expected: ImplicitMethodsQualificationOracle.euler(stiff, q: 0, v: 1, h: 0.2), model: stiffModel, time: 0.2)
            try ImplicitMethodsQualificationFixtures.require(stiffResult.endpoint.point[1] > 0 && stiffResult.endpoint.point[1] < 0.05,
                "Stiff positive velocity decay without explicit instability or method substitution.")
            let nonlinear = try ImplicitQualificationPhysics(cubicStiffness: 3), nonlinearModel = try ImplicitMethodsQualificationFixtures.model(nonlinear)
            let nonlinearSession = try ImplicitMethodsQualificationFixtures.session(nonlinearModel, physics: nonlinear, q: 0.7, v: -0.2)
            defer { _ = nonlinearSession.shutdown() }
            let nonlinearResult = try ReferenceImplicitEulerIntegrator().step(nonlinearSession, model: nonlinearModel,
                equations: ImplicitQualificationODE(model: nonlinearModel, physics: nonlinear), to: h,
                policy: ImplicitMethodsQualificationFixtures.eulerPolicy())
            let nonlinearExpected = try ImplicitMethodsQualificationOracle.nonlinearEuler(nonlinear, q: 0.7, v: -0.2, h: h)
            try endpoint(nonlinearResult, expected: nonlinearExpected, model: nonlinearModel, time: h)
            try ImplicitMethodsQualificationFixtures.near(nonlinear.originalBalance(q: nonlinearResult.endpoint.point[0], v: nonlinearResult.endpoint.point[1],
                a: (nonlinearResult.endpoint.point[1]+0.2)/h), 0, "Original nonlinear Euler mass/spring/damping/load balance.")
        }
    }
    public static func eulerOrderAndRepeat() throws(ImplicitMethodsQualificationError) {
        try ImplicitMethodsQualificationFixtures.translated {
            let physics = try ImplicitQualificationPhysics(mass: 1, stiffness: 1, damping: 0, constantLoad: 0)
            let model = try ImplicitMethodsQualificationFixtures.model(physics), equation = try ImplicitQualificationODE(model: model, physics: physics)
            let policy = try ImplicitMethodsQualificationFixtures.eulerPolicy(), exact = ImplicitMethodsQualificationOracle.oscillatorAtOne()
            var errors: [Double] = []
            for count in [20, 40, 80] {
                let session = try ImplicitMethodsQualificationFixtures.session(model, physics: physics, q: 1, v: 0)
                defer { _ = session.shutdown() }
                var q = 1.0, v = 0.0
                for i in 0..<count {
                    let time = Double(i+1)/Double(count), oldTime = Double(i)/Double(count)
                    let expected = ImplicitMethodsQualificationOracle.euler(physics, q: q, v: v, h: time-oldTime)
                    let result = try ReferenceImplicitEulerIntegrator().step(session, model: model, equations: equation, to: time, policy: policy)
                    try endpoint(result, expected: expected, model: model, time: time); q = expected.q; v = expected.v
                }
                let state = session.snapshot().checkpoint.physical
                errors.append(max(abs(state.q[0]-exact.q), abs(state.v[0]-exact.v)))
                try ImplicitMethodsQualificationFixtures.require(state.time == 1 && session.snapshot().checkpoint.random.draws == UInt64(count)
                    && session.snapshot().checkpoint.contributors[0].bytes == [UInt8(count)], "Uninterrupted accepted preparation history.")
            }
            for i in 0..<2 { try ImplicitMethodsQualificationFixtures.require(errors[i]/errors[i+1] >= 1.8
                && errors[i]/errors[i+1] <= 2.2, "Independent oscillator first-order convergence ratio.") }
            let first = try ImplicitMethodsQualificationFixtures.session(model, physics: physics)
            let second = try ImplicitMethodsQualificationFixtures.session(model, physics: physics)
            defer { _ = first.shutdown(); _ = second.shutdown() }
            let a = try ReferenceImplicitEulerIntegrator().step(first, model: model, equations: equation, to: 0.1, policy: policy)
            let b = try ReferenceImplicitEulerIntegrator().step(second, model: model, equations: equation, to: 0.1, policy: policy)
            try ImplicitMethodsQualificationFixtures.require(a.accepted == b.accepted && a.endpoint.point == b.endpoint.point
                && a.endpoint.work == b.endpoint.work, "Fresh identical input preserves complete same-build result/work.")
        }
    }
    public static func generalizedAlphaEndpoints() throws(ImplicitMethodsQualificationError) {
        try ImplicitMethodsQualificationFixtures.translated {
            let physics = try ImplicitQualificationPhysics(), model = try ImplicitMethodsQualificationFixtures.model(physics)
            let provider = try ImplicitQualificationStructural(model: model, physics: physics)
            let input = try ImplicitMethodsQualificationFixtures.structuralInput(provider)
            for rho in [1.0, 0.5, 0.0] {
                let parameters = try GeneralizedAlphaParameters(spectralRadiusInfinity: rho)
                let endpoint = try ReferenceStructuralImplicitStepper().step(input, equations: provider, to: 0.2,
                    policy: ImplicitMethodsQualificationFixtures.structuralPolicy(parameters))
                let expected = ImplicitMethodsQualificationOracle.structural(physics, q: input.displacement[0], v: input.velocity[0],
                    a: input.acceleration[0], h: 0.2, parameters: parameters)
                try structuralEndpoint(endpoint, expected: expected, descriptor: provider.descriptor, parameters: parameters, time: 0.2)
                let qf = (1-parameters.alphaF)*expected.q+parameters.alphaF*input.displacement[0]
                let vf = (1-parameters.alphaF)*expected.v+parameters.alphaF*input.velocity[0]
                let am = (1-parameters.alphaM)*expected.a+parameters.alphaM*input.acceleration[0]
                try ImplicitMethodsQualificationFixtures.near(physics.originalBalance(q: qf, v: vf, a: am), 0, "Original weighted generalized-alpha physical balance.")
            }
        }
    }
    public static func hhtOriginalEndpointsAndEnergy() throws(ImplicitMethodsQualificationError) {
        try ImplicitMethodsQualificationFixtures.translated {
            let physics = try ImplicitQualificationPhysics(cubicStiffness: 3), model = try ImplicitMethodsQualificationFixtures.model(physics)
            let provider = try ImplicitQualificationStructural(model: model, physics: physics)
            let input = try ImplicitMethodsQualificationFixtures.structuralInput(provider, q: 0.7, v: -0.2)
            for alpha in [-0.2, -1.0/3.0] {
                let parameters = try GeneralizedAlphaParameters.hht(alpha: alpha)
                let result = try ReferenceStructuralImplicitStepper().step(input, equations: provider, to: 0.3,
                    policy: ImplicitMethodsQualificationFixtures.structuralPolicy(parameters))
                let expected = try ImplicitMethodsQualificationOracle.nonlinearHHT(physics, q: input.displacement[0], v: input.velocity[0],
                    a: input.acceleration[0], h: 0.3, parameters: parameters)
                try structuralEndpoint(result, expected: expected, descriptor: provider.descriptor, parameters: parameters, time: 0.3)
                let balance = (1-parameters.alphaF)*physics.originalBalance(q: expected.q, v: expected.v, a: expected.a)
                    + parameters.alphaF*physics.originalBalance(q: input.displacement[0], v: input.velocity[0], a: expected.a)
                try ImplicitMethodsQualificationFixtures.near(balance, 0, "Independent original two-endpoint nonlinear HHT balance.")
                let wrong = physics.originalBalance(q: (1-parameters.alphaF)*expected.q+parameters.alphaF*input.displacement[0],
                    v: (1-parameters.alphaF)*expected.v+parameters.alphaF*input.velocity[0], a: expected.a)
                try ImplicitMethodsQualificationFixtures.require(abs(wrong) > 1e-4, "Nonlinear endpoint weighting must not become a weighted-state replacement.")
            }
            let oscillator = try ImplicitQualificationPhysics(mass: 1, stiffness: 1, damping: 0, constantLoad: 0)
            let oscillatorModel = try ImplicitMethodsQualificationFixtures.model(oscillator)
            let oscillatorProvider = try ImplicitQualificationStructural(model: oscillatorModel, physics: oscillator)
            let parameters = try GeneralizedAlphaParameters.hht(alpha: 0)
            var current = try ImplicitMethodsQualificationFixtures.structuralInput(oscillatorProvider, q: 1, v: 0)
            let initialEnergy = ImplicitMethodsQualificationOracle.energy(oscillator, q: 1, v: 0)
            for i in 1...32 {
                let result = try ReferenceStructuralImplicitStepper().step(current, equations: oscillatorProvider, to: Double(i)/32,
                    policy: ImplicitMethodsQualificationFixtures.structuralPolicy(parameters))
                let expected = ImplicitMethodsQualificationOracle.structural(oscillator, q: current.displacement[0], v: current.velocity[0],
                    a: current.acceleration[0], h: Double(i)/32-current.time, parameters: parameters)
                try structuralEndpoint(result, expected: expected, descriptor: oscillatorProvider.descriptor, parameters: parameters, time: Double(i)/32)
                try ImplicitMethodsQualificationFixtures.near(ImplicitMethodsQualificationOracle.energy(oscillator, q: result.state.displacement[0], v: result.state.velocity[0]),
                    initialEnergy, "HHT alpha-zero actual nondissipative trapezoidal physical energy.")
                current = result.state
            }
        }
    }
    public static func providerRefusalAndRollback() throws(ImplicitMethodsQualificationError) {
        try ImplicitMethodsQualificationFixtures.translated {
            let physics = try ImplicitQualificationPhysics(), model = try ImplicitMethodsQualificationFixtures.model(physics)
            let policy = try ImplicitMethodsQualificationFixtures.eulerPolicy()
            for fault in [ImplicitQualificationFault.prepareFailure, .preparePhysicalMutation, .missingDerivative, .wrongTangent, .writeMismatch, .resetLedger, .unavailableFailure] {
                let session = try ImplicitMethodsQualificationFixtures.session(model, physics: physics)
                defer { _ = session.shutdown() }
                let equation = try ImplicitQualificationODE(model: model, physics: physics, fault: fault)
                try eulerFailure(session, model: model, equation: equation, policy: policy, unavailable: fault == .resetLedger || fault == .unavailableFailure) { cause in
                    switch (fault, cause) {
                    case (.prepareFailure, .runtime(let failure)), (.unavailableFailure, .runtime(let failure)): failure.code == .invalidState
                    case (.preparePhysicalMutation, .invalidEvaluation), (.writeMismatch, .invalidEvaluation), (.resetLedger, .invalidOwnerAccess): true
                    case (.missingDerivative, .nonlinear(let failure)): failure.cause == .invalidEvaluation
                    case (.wrongTangent, .nonlinear(let failure)): if case .invalidDerivative = failure.cause { true } else { false }
                    default: false
                    }
                }
                let healthy = try ImplicitQualificationODE(model: model, physics: physics)
                let recovered = try ReferenceImplicitEulerIntegrator().step(session, model: model, equations: healthy, to: 0.2, policy: policy)
                try endpoint(recovered, expected: ImplicitMethodsQualificationOracle.euler(physics, q: 0.25, v: -0.2, h: 0.2), model: model, time: 0.2)
                try ImplicitMethodsQualificationFixtures.require(recovered.accepted.checkpoint.random.draws == 1
                    && recovered.accepted.checkpoint.contributors[0].bytes == [1], "Failed preparation did not leak into recovered publication.")
            }
            for fault in [ImplicitQualificationFault.wrongTangent, .originalBalanceMismatch, .resetLedger, .unavailableFailure] {
                let provider = try ImplicitQualificationStructural(model: model, physics: physics, fault: fault)
                let input = try ImplicitMethodsQualificationFixtures.structuralInput(provider)
                try structuralFailure(input, provider: provider, policy: ImplicitMethodsQualificationFixtures.structuralPolicy(.hht(alpha: -0.2)),
                    unavailable: fault == .resetLedger || fault == .unavailableFailure) { cause in
                    switch (fault, cause) {
                    case (.resetLedger, .invalidOwnerAccess): true
                    case (.unavailableFailure, .runtime(let error)): error.code == .invalidState
                    case (.wrongTangent, .nonlinear(let error)): if case .invalidDerivative = error.cause { true } else { false }
                    case (.originalBalanceMismatch, .nonlinear(let error)): if case .originalResidualDisagreement = error.cause { true } else { false }
                    default: false
                    }
                }
            }
        }
    }
    public static func domainAndExclusiveOwner() throws(ImplicitMethodsQualificationError) {
        try ImplicitMethodsQualificationFixtures.translated {
            let physics = try ImplicitQualificationPhysics(), model = try ImplicitMethodsQualificationFixtures.model(physics)
            let session = try ImplicitMethodsQualificationFixtures.session(model, physics: physics)
            defer { _ = session.shutdown() }
            let equation = try ImplicitQualificationODE(model: model, physics: physics), policy = try ImplicitMethodsQualificationFixtures.eulerPolicy()
            try eulerFailure(session, model: model, equation: ImplicitQualificationODE(model: model, physics: physics, domain: .manifold), policy: policy) {
                if case .unsupportedDomain = $0 { true } else { false }
            }
            let staleModel = try ImplicitMethodsQualificationFixtures.model(physics, revision: 98)
            try eulerFailure(session, model: model, equation: ImplicitQualificationODE(model: staleModel, physics: physics), policy: policy) {
                if case .invalidInput = $0 { true } else { false }
            }
            try eulerFailure(session, model: model, equation: equation, policy: policy, time: 0) { if case .invalidInput = $0 { true } else { false } }
            let continued = try ImplicitMethodsQualificationFixtures.session(model, physics: physics, category: .integrator)
            defer { _ = continued.shutdown() }
            try eulerFailure(continued, model: model, equation: equation, policy: policy) { if case .unsupportedDomain = $0 { true } else { false } }
            let before = session.snapshot()
            // Use a real Runtime observation lease to force nonqueuing exclusive trial admission.
            try session.observe { _ throws(RuntimeFailure) in
                let captured: ImplicitIntegrationFailure?
                do throws(ImplicitIntegrationFailure) {
                    _ = try ReferenceImplicitEulerIntegrator().step(session, model: model, equations: equation, to: 0.2, policy: policy)
                    captured = nil
                } catch {
                    captured = error
                }
                guard let captured, case .runtime(let failure) = captured.cause, failure.code == .busy, captured.lastAccepted == before else {
                    throw RuntimeFailure(.invalidState, message: "Expected actual exclusive-owner busy refusal.")
                }
            }
            try ImplicitMethodsQualificationFixtures.require(session.snapshot() == before, "Owner-busy refusal preserves accepted state.")
            for domain in [StructuralMassDomain.variableMass] {
                let provider = try ImplicitQualificationStructural(model: model, physics: physics, massDomain: domain)
                try structuralFailure(ImplicitMethodsQualificationFixtures.structuralInput(provider), provider: provider,
                    policy: ImplicitMethodsQualificationFixtures.structuralPolicy(.hht(alpha: 0))) { if case .unsupportedDomain = $0 { true } else { false } }
            }
        }
    }
    public static func budgetsAndCallbackCancellation() throws(ImplicitMethodsQualificationError) {
        try ImplicitMethodsQualificationFixtures.translated {
            let physics = try ImplicitQualificationPhysics(), model = try ImplicitMethodsQualificationFixtures.model(physics)
            let equation = try ImplicitQualificationODE(model: model, physics: physics)
            for variant in 0..<4 {
                let session = try ImplicitMethodsQualificationFixtures.session(model, physics: physics, stepWork: variant == 3 ? 0 : 10000)
                defer { _ = session.shutdown() }
                let policy = try ImplicitMethodsQualificationFixtures.eulerPolicy(operations: variant == 1 ? 1 : 200000,
                    storage: variant == 0 ? 1 : 4096, iterations: variant == 2 ? 0 : 256)
                try eulerFailure(session, model: model, equation: equation, policy: policy) { cause in
                    switch cause {
                    case .numerical(.resourceLimit): true
                    case .nonlinear(let error): if case .numerical(.resourceLimit) = error.cause { true } else { false }
                    case .runtime(let error): variant == 3 && error.code == .capacityExceeded
                    default: false
                    }
                }
            }
            let session = try ImplicitMethodsQualificationFixtures.session(model, physics: physics)
            defer { _ = session.shutdown() }
            let cancelling = try ImplicitQualificationODE(model: model, physics: physics, onDerivative: { session.cancel() })
            try eulerFailure(session, model: model, equation: cancelling, policy: ImplicitMethodsQualificationFixtures.eulerPolicy()) {
                if case .runtime(let error) = $0 { return error.code == .cancelled }; return false
            }
            let recovered = try ReferenceImplicitEulerIntegrator().step(session, model: model, equations: equation, to: 0.2,
                policy: ImplicitMethodsQualificationFixtures.eulerPolicy())
            try endpoint(recovered, expected: ImplicitMethodsQualificationOracle.euler(physics, q: 0.25, v: -0.2, h: 0.2), model: model, time: 0.2)
            let equilibrium = try ImplicitMethodsQualificationFixtures.session(model, physics: physics, q: 0.15, v: 0)
            defer { _ = equilibrium.shutdown() }
            let accepted = try ReferenceImplicitEulerIntegrator().step(equilibrium, model: model, equations: equation, to: 0.2,
                policy: ImplicitMethodsQualificationFixtures.eulerPolicy(iterations: 0))
            try ImplicitMethodsQualificationFixtures.require(accepted.endpoint.originalResidual.isAccepted
                && accepted.endpoint.nonlinearDiagnostics.nonlinearIterations == 0
                && accepted.endpoint.nonlinearDiagnostics.originalEvaluations == 1, "Initial physical equilibrium still independently accepts original residual.")
            let provider = try ImplicitQualificationStructural(model: model, physics: physics)
            let input = try ImplicitMethodsQualificationFixtures.structuralInput(provider)
            for policy in [try ImplicitMethodsQualificationFixtures.structuralPolicy(.hht(alpha: 0), storage: 1),
                           try ImplicitMethodsQualificationFixtures.structuralPolicy(.hht(alpha: 0), operations: 1),
                           try ImplicitMethodsQualificationFixtures.structuralPolicy(.hht(alpha: 0), iterations: 0)] {
                try structuralFailure(input, provider: provider, policy: policy) { cause in
                    if case .numerical(.resourceLimit) = cause { return true }
                    if case .nonlinear(let failure) = cause, case .numerical(.resourceLimit) = failure.cause { return true }
                    return false
                }
            }
        }
    }
    private static func endpoint(_ result: ImplicitEulerStepResult, expected: (q: Double, v: Double, a: Double),
                                 model: CompiledMechanicalModel, time: Double) throws(ImplicitMethodsQualificationError) {
        let near = ImplicitMethodsQualificationFixtures.near
        let state = result.accepted.checkpoint.physical
        try ImplicitMethodsQualificationFixtures.require(result.accepted.physical.stamp == model.stamp && state.revision == model.stamp.revision
            && result.endpoint.time == time && state.time == time && result.endpoint.originalResidual.isAccepted, "Original model/clock and physical residual acceptance.")
        try near(result.endpoint.point[0], expected.q, 2e-10, 2e-10, "Original implicit coordinate vs physical closed form.")
        try near(result.endpoint.point[1], expected.v, 2e-10, 2e-10, "Original implicit velocity vs physical closed form.")
        try near(result.endpoint.derivative[0], expected.v, 2e-10, 2e-10, "Fresh endpoint coordinate derivative.")
        try near(result.endpoint.derivative[1], expected.a, 2e-10, 2e-10, "Fresh original force acceleration.")
        try near(state.q[0], expected.q, 2e-10, 2e-10, "Actual accepted Runtime coordinate.")
        try near(state.v[0], expected.v, 2e-10, 2e-10, "Actual accepted Runtime velocity.")
        try near(state.acceleration[0], expected.a, 2e-10, 2e-10, "Actual accepted Runtime acceleration.")
        try ImplicitMethodsQualificationFixtures.require(result.endpoint.work.operations > result.endpoint.nonlinearDiagnostics.work.operations
            && result.endpoint.work.operations <= result.endpoint.work.budget.arithmeticOperations, "Outer/provider/final original work retained.")
    }
    private static func structuralEndpoint(_ result: StructuralImplicitEndpoint, expected: (q: Double, v: Double, a: Double),
                                           descriptor: ODEDescriptor, parameters: GeneralizedAlphaParameters, time: Double)
        throws(ImplicitMethodsQualificationError) {
        let near = ImplicitMethodsQualificationFixtures.near
        try ImplicitMethodsQualificationFixtures.require(result.state.descriptor == descriptor && result.state.time == time
            && result.parameters == parameters && result.originalResidual.isAccepted, "Structural original descriptor/clock/parameters/residual.")
        try near(result.state.displacement[0], expected.q, 2e-10, 2e-10, "Original structural displacement vs independent solve.")
        try near(result.state.velocity[0], expected.v, 2e-10, 2e-10, "Original structural velocity vs independent solve.")
        try near(result.state.acceleration[0], expected.a, 2e-10, 2e-10, "Original structural acceleration vs independent solve.")
        try ImplicitMethodsQualificationFixtures.require(result.work.operations >= result.nonlinearDiagnostics.work.operations
            && result.work.operations <= result.work.budget.arithmeticOperations, "Structural known composed work.")
    }
    public static func eulerFailure(_ session: ImplicitMethodsQualificationFixtures.Session, model: CompiledMechanicalModel,
                                     equation: ImplicitQualificationODE, policy: ImplicitEulerPolicy, time: Double = 0.2,
                                     unavailable: Bool = false, matches: (ImplicitMethodCause) -> Bool)
        throws(ImplicitMethodsQualificationError) {
        let initial = session.snapshot()
        do throws(ImplicitIntegrationFailure) {
            _ = try ReferenceImplicitEulerIntegrator().step(session, model: model, equations: equation, to: time, policy: policy)
        } catch {
            try ImplicitMethodsQualificationFixtures.require(matches(error.cause), "Original Euler typed refusal cause.")
            try ImplicitMethodsQualificationFixtures.require(error.lastAccepted == initial && session.snapshot() == initial,
                "Complete original Runtime checkpoint/random/contributor rollback.")
            try ImplicitMethodsQualificationFixtures.require(error.work.budget == policy.nonlinear.budget
                && error.work.operations <= policy.nonlinear.budget.arithmeticOperations && error.work.peakScalarStorage <= policy.nonlinear.budget.scalarStorage
                && error.failedSupplierWorkUnavailable == unavailable, "Original known work/unavailable failure identity.")
            return
        }
        throw .assertion("Expected original Euler failure, not publication.")
    }
    private static func structuralFailure(_ input: StructuralIntegrationState, provider: ImplicitQualificationStructural,
                                          policy: StructuralImplicitPolicy, unavailable: Bool = false,
                                          matches: (ImplicitMethodCause) -> Bool) throws(ImplicitMethodsQualificationError) {
        do throws(StructuralImplicitFailure) { _ = try ReferenceStructuralImplicitStepper().step(input, equations: provider, to: 0.2, policy: policy) }
        catch {
            try ImplicitMethodsQualificationFixtures.require(matches(error.cause), "Original structural typed refusal cause.")
            try ImplicitMethodsQualificationFixtures.require(error.input.descriptor == input.descriptor && error.input.time == input.time
                && error.input.displacement == input.displacement && error.input.velocity == input.velocity && error.input.acceleration == input.acceleration,
                "Immutable structural input preserved.")
            try ImplicitMethodsQualificationFixtures.require(error.work.budget == policy.nonlinear.budget
                && error.work.operations <= error.work.budget.arithmeticOperations && error.work.peakScalarStorage <= error.work.budget.scalarStorage
                && error.failedSupplierWorkUnavailable == unavailable, "Original structural known work/unavailability.")
            return
        }
        throw .assertion("Expected original structural failure.")
    }
}
