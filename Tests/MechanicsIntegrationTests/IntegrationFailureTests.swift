import Testing
import MechanicsRuntime
import MechanicsIntegration

@Suite struct IntegrationFailureTests {
    @Test func supplierLedgerReplacementAndResetCannotPublishOrRetry() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        let model = try IntegrationFixtures.model()
        for fault in [ManufacturedHingeEquation.LedgerFault.replaceInPrepare, .resetInDerivative] {
            let equation = try ManufacturedHingeEquation(model: model, prepareSubsystem: true, ledgerFault: fault)
            let policy = try IntegrationFixtures.policy(method: .heunEuler, step: 0.5, tolerance: 1e-8)
            let (session, continuation) = try IntegrationFixtures.session(model: model, equation: equation, policy: policy)
            let prefix = session.snapshot()
            let failed = try #require(IntegrationFixtures.failure(.invalidOwnerAccess) { () throws(IntegrationFailure) in
                _ = try ReferenceExplicitIntegrator().advance(session, model: model, equations: equation, continuation: continuation, to: 1)
            })
            #expect(failed.work.failedSupplierWorkUnavailable)
            #expect(failed.lastAccepted == prefix && session.snapshot() == prefix)
            #expect(failed.acceptedSteps == 0 && failed.rejectedTrials == 0)
            #expect(session.profile().attemptedTransactions == 1 && session.profile().failedTransactions == 1)
            #expect(failed.work.supplierArithmeticCharged == (fault == .replaceInPrepare ? 0 : 1))
        }
    }
    @Test func nestedFailurePreservesKnownChargesAndUnknownWorkWithoutRetry() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        let model = try IntegrationFixtures.model()
        let equation = try ManufacturedHingeEquation(model: model, prepareSubsystem: true, ledgerFault: .nestedFailure)
        let (session, continuation) = try IntegrationFixtures.session(model: model, equation: equation, policy: IntegrationFixtures.policy())
        let prefix = session.snapshot()
        let failed = try #require(IntegrationFixtures.failure(.invalidState) { () throws(IntegrationFailure) in
            _ = try ReferenceExplicitIntegrator().advance(session, model: model, equations: equation, continuation: continuation, to: 1)
        })
        #expect(failed.work.failedSupplierWorkUnavailable)
        #expect(failed.work.supplierArithmeticCharged == 3 && failed.work.derivativeCalls == 1)
        #expect(failed.lastAccepted == prefix && session.snapshot() == prefix)
        #expect(session.profile().attemptedTransactions == 1 && failed.acceptedSteps == 0 && failed.rejectedTrials == 0)
    }
    @Test func malformedDerivativeSupplierOuterAndRuntimeBudgetsAreTerminal() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        let model = try IntegrationFixtures.model()
        for scenario in 0..<4 {
            let eq = try ManufacturedHingeEquation(model: model,malformed: scenario == 0)
            let policy = try IntegrationFixtures.policy(outer: scenario == 1 ? 0 : 100000,supplier: scenario == 2 ? 0 : 100000)
            let (session,c) = try IntegrationFixtures.session(model: model,equation: eq,policy: policy,work: scenario == 3 ? 0 : 1000)
            let prefix = session.snapshot()
            let failed = try #require(IntegrationFixtures.failure(scenario == 0 ? .invalidState : .capacityExceeded) { () throws(IntegrationFailure) in
                _ = try ReferenceExplicitIntegrator().advance(session,model: model,equations: eq,continuation: c,to: 0.1)
            })
            #expect(failed.lastAccepted == prefix && session.snapshot() == prefix)
            #expect(session.profile().attemptedTransactions == 1)
        }
    }
    @Test func retryMinimumAndAcceptedStepLimitsReturnRealPrefix() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        let model = try IntegrationFixtures.model(), eq = try ManufacturedHingeEquation(model: model,prepareSubsystem: true)
        for policy in [try IntegrationFixtures.policy(method: .heunEuler,step: 0.5,tolerance: 1e-12,minimum: 0.1),
                       try IntegrationFixtures.policy(method: .heunEuler,step: 0.5,tolerance: 1e-8,attempts: 1),
                       try IntegrationFixtures.policy(step: 0.1,steps: 1)] {
            let (session,c) = try IntegrationFixtures.session(model: model,equation: eq,policy: policy)
            let failed = try #require(IntegrationFixtures.failure(.capacityExceeded) { () throws(IntegrationFailure) in
                _ = try ReferenceExplicitIntegrator().advance(session,model: model,equations: eq,continuation: c,to: 1)
            })
            #expect(failed.lastAccepted == session.snapshot())
            #expect(session.snapshot().checkpoint.random.draws == UInt64(failed.acceptedSteps))
            if policy.method == .classicalRK4 { #expect(failed.acceptedSteps == 1 && failed.lastAccepted.checkpoint.physical.time == 0.1) }
            else { #expect(failed.acceptedSteps == 0 && failed.lastAccepted.checkpoint.physical.time == 0) }
        }
    }
    @Test func cancellationDuringDerivativeCannotPublishPreparedSubsystem() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        let model = try IntegrationFixtures.model(), plain = try ManufacturedHingeEquation(model: model,prepareSubsystem: true)
        let (session,c) = try IntegrationFixtures.session(model: model,equation: plain,policy: IntegrationFixtures.policy())
        let cancel = try ManufacturedHingeEquation(model: model,prepareSubsystem: true,onDerivative: { session.cancel() })
        let prefix = session.snapshot()
        let failed = try #require(IntegrationFixtures.failure(.cancelled) { () throws(IntegrationFailure) in
            _ = try ReferenceExplicitIntegrator().advance(session,model: model,equations: cancel,continuation: c,to: 0.1)
        }); #expect(failed.lastAccepted == prefix && session.snapshot() == prefix)
        _ = try ReferenceExplicitIntegrator().step(session,model: model,equations: plain,continuation: c)
        #expect(session.snapshot().checkpoint.random.draws == 1)
    }
}
