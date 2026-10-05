import Testing
import SwiftMechanics

@Suite struct TabulatedDamperTests {
    let service: any TabulatedDamperEvaluating = TabulatedDamperEvaluator()
    func law() throws -> TabulatedDamperLaw {
        var work = try NineServiceFixture.work()
        return try TabulatedDamperLaw(coordinateKind: .translation, rates: [-2,-1,0,1,2],
            restoringEfforts: [-8,-2,0,3,10], maximumKnots: 5, work: &work)
    }
    func evaluate(_ sample: Double) throws -> TabulatedDamperResponse {
        var work = try NineServiceFixture.work()
        return try service.evaluate(law: law(), rate: sample, work: &work)
    }
    @Test func independentPiecewisePhysicalResponse() throws {
        let r = try evaluate(-1.5)
        #expect(NineServiceFixture.near(r.effort, 5))
        #expect(NineServiceFixture.near(r.dissipatedPower, 7.5))
        let positive = try evaluate(0.5)
        #expect(NineServiceFixture.near(positive.dissipatedPower, 0.75))
        #expect(try evaluate(0).dissipatedPower == 0)
    }
    @Test func originalDirectionalDerivative() throws {
        let x = -1.5, h = 1e-5, r = try evaluate(x)
        let plus = try evaluate(x+h), minus = try evaluate(x-h)
        #expect(NineServiceFixture.near(r.leftRateDerivative!, (plus.effort-minus.effort)/(2*h)))
        #expect(r.leftRateDerivative == r.rightRateDerivative)
        #expect(NineServiceFixture.near(r.dissipatedPower, -r.effort*x))
    }
    @Test func knotBranchesAndEndpointAuthority() throws {
        let negative = try evaluate(-1), zero = try evaluate(0)
        #expect(negative.leftRateDerivative == -6 && negative.rightRateDerivative == -2)
        #expect(zero.leftRateDerivative == -2 && zero.rightRateDerivative == -3)
        #expect(try evaluate(-2).leftRateDerivative == nil)
        #expect(try evaluate(2).rightRateDerivative == nil)
        #expect(try evaluate(2).leftRateDerivative == -7)
        let h = 1e-6
        #expect(NineServiceFixture.near((try evaluate(h).effort-zero.effort)/h, -3))
        #expect(NineServiceFixture.near((zero.effort - (try evaluate(-h).effort))/h, -2))
    }
    @Test func calibrationEnvelopeAndFiniteRefusals() throws {
        var work = try NineServiceFixture.work()
        #expect(throws: LoadError.invalidPassiveLaw) {
            try TabulatedDamperLaw(coordinateKind: .translation, rates: [-1,0,1], restoringEfforts: [-1,1,2], maximumKnots: 3, work: &work)
        }
        #expect(throws: LoadError.invalidPassiveLaw) {
            try TabulatedDamperLaw(coordinateKind: .translation, rates: [-1,0,0], restoringEfforts: [-1,0,1], maximumKnots: 3, work: &work)
        }
        #expect(throws: LoadError.invalidPassiveLaw) {
            try TabulatedDamperLaw(coordinateKind: .translation, rates: [-1,0,1], restoringEfforts: [-1,0,-2], maximumKnots: 3, work: &work)
        }
        #expect(throws: LoadError.outsideDomain) { try evaluate(2.01) }
        #expect(throws: LoadError.invalidInput) { try evaluate(.nan) }
        #expect(throws: LoadError.nonFiniteResult) {
            try TabulatedDamperLaw(coordinateKind: .translation, rates: [0,1e-308,1], restoringEfforts: [0,1e308,1e308], maximumKnots: 3, work: &work)
            
        }
    }
    @Test func boundedConstructionAndQueryPreserveLaw() throws {
        let p = try law(), original = p
        var small = try NineServiceFixture.work(maximumScalars: 0)
        #expect(throws: LoadError.capacityExceeded) {
            try TabulatedDamperLaw(coordinateKind: .translation, rates: [-1,0,1], restoringEfforts: [-1,0,1], maximumKnots: 3, work: &small)
        }
        var exhausted = try NineServiceFixture.work(maximumWork: 0)
        #expect(throws: LoadError.workExhausted) { try service.evaluate(law: p, rate: 0.5, work: &exhausted) }
        var cancelled = try NineServiceFixture.work(cancelled: true)
        #expect(throws: LoadError.cancelled) { try service.evaluate(law: p, rate: 0.5, work: &cancelled) }
        #expect(p == original)
    }
    @Test func tinySignedSamplesPreserveOriginalCalibration() throws {
        let negative = try evaluate(-1e-20), positive = try evaluate(1e-20)
        #expect(NineServiceFixture.near(negative.effort, 2e-20, absolute: 1e-32))
        #expect(NineServiceFixture.near(positive.effort, -3e-20, absolute: 1e-32))
        #expect(NineServiceFixture.near(negative.dissipatedPower, 2e-40, absolute: 1e-52))
    }
}
