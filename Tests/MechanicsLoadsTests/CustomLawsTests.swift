import SwiftMechanics
import Testing
@Suite struct CustomLawsTests {
    private func policy() throws -> CustomLoadPolicy {
        try CustomLoadPolicy(minimumCoordinate: -2, maximumCoordinate: 2, maximumAbsoluteRate: 3,
            coordinateProbe: 1e-5, rateProbe: 1e-5, absoluteTolerance: 1e-8, relativeTolerance: 1e-8, requireConservativeEnergy: true)
    }
    @Test func immutableCallbackIndependentDerivativeAndEnergy() throws {
        let state = try CustomLoadState(revision: 3, values: [4])
        let service: any CustomLoadEvaluating = CustomLoadEvaluator()
        var work = try LoadFixtures.work(15)
        let r = try service.evaluate(CustomFixture(), state: state, coordinate: 0.7, rate: 0.3, policy: policy(), work: &work)
        #expect(abs(r.conservative + 0.343) < 1e-12 && r.dissipative == -0.6 && r.active == 4)
        #expect(abs(r.dissipatedPower - 0.18) < 1e-12)
        #expect(work.consumed == 15)
        let expected = try CustomLoadState(revision: 3, values: [4])
        #expect(state == expected)
    }
    @Test func customFailuresRemainTyped() throws {
        let state = try CustomLoadState(revision: 1, values: [0]), service = CustomLoadEvaluator()
        var work = try LoadFixtures.work()
        #expect(throws: LoadError.providerFailure(7)) { try service.evaluate(CustomFixture(failure: true), state: state, coordinate: 0.7, rate: 0.3, policy: policy(), work: &work) }
        #expect(throws: LoadError.derivativeMismatch) { try service.evaluate(CustomFixture(badDerivative: true), state: state, coordinate: 0.7, rate: 0.3, policy: policy(), work: &work) }
        #expect(throws: LoadError.missingEnergy) { try service.evaluate(CustomFixture(noEnergy: true), state: state, coordinate: 0.7, rate: 0.3, policy: policy(), work: &work) }
        #expect(throws: LoadError.derivativeMismatch) { try service.evaluate(CustomFixture(badEnergy: true), state: state, coordinate: 0.7, rate: 0.3, policy: policy(), work: &work) }
        #expect(throws: LoadError.outsideDomain) { try service.evaluate(CustomFixture(), state: state, coordinate: 2, rate: 0, policy: policy(), work: &work) }
        #expect(throws: LoadError.missingEnergy) { try service.evaluate(CustomFixture(noEnergy: true), state: state, coordinate: 0, rate: 0.3, policy: policy(), work: &work) }
        #expect(throws: LoadError.providerChanged) { try service.evaluate(ResettingCustomFixture(), state: state, coordinate: 0, rate: 0, policy: policy(), work: &work) }
        var small = try LoadFixtures.work(14)
        #expect(throws: LoadError.workExhausted) { try service.evaluate(CustomFixture(), state: state, coordinate: 0.7, rate: 0.3, policy: policy(), work: &small) }
        #expect(small.consumed == 13)
        #expect(throws: LoadError.invalidInput) { try ScalarLoadResponse(conservative: .nan, dissipative: 0, coordinateDerivative: 0, rateDerivative: 0, potentialEnergy: 0, dissipatedPower: 0) }
    }
    @available(macOS 15, *)
    @Test func metadataMutationRejected() throws {
        var work = try LoadFixtures.work()
        #expect(throws: LoadError.providerChanged) { try CustomLoadEvaluator().evaluate(ChangingCustomFixture(), state: CustomLoadState(revision: 0, values: []), coordinate: 0, rate: 0, policy: policy(), work: &work) }
    }
}
