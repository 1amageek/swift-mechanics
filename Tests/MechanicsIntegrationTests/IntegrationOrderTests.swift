import SwiftMechanics
import Testing
import Foundation

@Suite struct IntegrationOrderTests {
    @Test func classicalRK4AndHeunHaveIndependentObservedOrders() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        let model = try IntegrationFixtures.model(), equation = try ManufacturedHingeEquation(model: model)
        for method in [ExplicitIntegrationMethod.classicalRK4,.heunEuler] {
            var errors: [Double] = []
            for h in [0.2,0.1,0.05] {
                let policy = try IntegrationFixtures.policy(method: method,step: h,tolerance: 100,minimum: h,maximum: h)
                let (session,history) = try IntegrationFixtures.session(model: model,equation: equation,policy: policy)
                let service: any ExplicitIntegrating = ReferenceExplicitIntegrator()
                let result = try service.advance(session,model: model,equations: equation,continuation: history,to: 1)
                #expect(result.reachedRequestedTime && result.accepted.checkpoint.physical.time == 1)
                let state = result.accepted.checkpoint.physical
                errors.append(max(abs(state.q[0]-cos(1)),abs(state.v[0]+sin(1))))
                #expect(result.rejectedTrials == 0 && result.work.derivativeCalls >= result.acceptedSteps * 3)
            }
            let lower = method == .classicalRK4 ? 13.0 : 3.5, upper = method == .classicalRK4 ? 20.0 : 5.0
            #expect(errors[0]/errors[1] > lower && errors[0]/errors[1] < upper)
            #expect(errors[1]/errors[2] > lower && errors[1]/errors[2] < upper)
        }
    }
    @Test func adaptiveDimensionalErrorMeetsAnalyticDecayAndTerminalTime() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        let model = try IntegrationFixtures.model(), equation = try ManufacturedHingeEquation(model: model,coefficient: 4)
        let policy = try IntegrationFixtures.policy(method: .heunEuler,step: 0.5,tolerance: 1e-6)
        let (session,history) = try IntegrationFixtures.session(model: model,equation: equation,policy: policy,q: 1,v: -2)
        let result = try ReferenceExplicitIntegrator().advance(session,model: model,equations: equation,continuation: history,to: 1)
        #expect(result.reachedRequestedTime && result.rejectedTrials > 0)
        #expect(abs(result.accepted.checkpoint.physical.q[0]-exp(-2)) < 2e-6)
        #expect(abs(result.accepted.checkpoint.physical.v[0]+2*exp(-2)) < 4e-6)
        #expect(result.lastNormalizedError != nil && result.lastNormalizedError! <= 1)
        let stored = try history.history(result.accepted.checkpoint.contributors.first(where: { $0.id == history.schema.id })!)
        #expect(stored.acceptedTime == 1 && stored.acceptedSteps == UInt64(result.acceptedSteps))
    }
    @Test func terminalShortStepAndNoOpAreExactAcceptedTime() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        let model = try IntegrationFixtures.model(), eq = try ManufacturedHingeEquation(model: model)
        let (session,c) = try IntegrationFixtures.session(model: model,equation: eq,policy: IntegrationFixtures.policy(step: 0.1,minimum: 0.01))
        let service = ReferenceExplicitIntegrator(), prefix = session.snapshot()
        let noOp = try service.advance(session,model: model,equations: eq,continuation: c,to: 0)
        #expect(noOp.accepted == prefix && noOp.acceptedSteps == 0)
        let result = try service.advance(session,model: model,equations: eq,continuation: c,to: 0.105)
        #expect(result.accepted.checkpoint.physical.time == 0.105 && result.acceptedSteps == 2)
        let failed = try #require(IntegrationFixtures.failure(.invalidInput) { () throws(IntegrationFailure) in
            _ = try service.advance(session,model: model,equations: eq,continuation: c,to: 0.1)
        }); #expect(failed.lastAccepted == result.accepted)
    }
}
