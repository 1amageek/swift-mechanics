import Testing
import SwiftMechanics

@Suite struct TabulatedSpringTests {
    let service: any TabulatedSpringEvaluating = TabulatedSpringEvaluator()
    func law() throws -> TabulatedSpringLaw {
        var work = try NineServiceFixture.work()
        return try TabulatedSpringLaw(coordinateKind: .translation, restCoordinate: 0, maximumRate: 5, displacements: [-2,-1,0,1,2],
            restoringEfforts: [-8,-2,0,3,10], maximumKnots: 5, work: &work)
    }
    func evaluate(_ sample: Double) throws -> TabulatedSpringResponse {
        var work = try NineServiceFixture.work()
        return try service.evaluate(law: law(), coordinate: sample, rate: 0, work: &work)
    }
    @Test func independentPiecewisePhysicalResponse() throws {
        let r = try evaluate(-1.5)
        #expect(NineServiceFixture.near(r.effort, 5))
        #expect(NineServiceFixture.near(r.potentialEnergy, 2.75))
        let positive = try evaluate(0.5)
        #expect(NineServiceFixture.near(positive.effort, -1.5))
        #expect(NineServiceFixture.near(positive.potentialEnergy, 0.375))
        #expect(NineServiceFixture.near(try evaluate(-2).potentialEnergy, 6))
        #expect(NineServiceFixture.near(try evaluate(2).potentialEnergy, 8))
    }
    @Test func originalDirectionalDerivative() throws {
        let x = -1.5, h = 1e-5, r = try evaluate(x)
        let plus = try evaluate(x+h), minus = try evaluate(x-h)
        #expect(NineServiceFixture.near(r.leftCoordinateDerivative!, (plus.effort-minus.effort)/(2*h)))
        #expect(r.leftCoordinateDerivative == r.rightCoordinateDerivative)
        #expect(NineServiceFixture.near(r.effort, -(plus.potentialEnergy-minus.potentialEnergy)/(2*h)))
    }
    @Test func knotBranchesAndEndpointAuthority() throws {
        let negative = try evaluate(-1), zero = try evaluate(0)
        #expect(negative.leftCoordinateDerivative == -6 && negative.rightCoordinateDerivative == -2)
        #expect(zero.leftCoordinateDerivative == -2 && zero.rightCoordinateDerivative == -3)
        #expect(try evaluate(-2).leftCoordinateDerivative == nil)
        #expect(try evaluate(2).rightCoordinateDerivative == nil)
        #expect(try evaluate(2).leftCoordinateDerivative == -7)
        let h = 1e-6
        #expect(NineServiceFixture.near((try evaluate(h).effort-zero.effort)/h, -3))
        #expect(NineServiceFixture.near((zero.effort - (try evaluate(-h).effort))/h, -2))
    }
    @Test func calibrationEnvelopeAndFiniteRefusals() throws {
        var work = try NineServiceFixture.work()
        #expect(throws: LoadError.invalidPassiveLaw) {
            try TabulatedSpringLaw(coordinateKind: .translation, restCoordinate: 0, maximumRate: 5, displacements: [-1,0,1], restoringEfforts: [-1,1,2], maximumKnots: 3, work: &work)
        }
        #expect(throws: LoadError.invalidPassiveLaw) {
            try TabulatedSpringLaw(coordinateKind: .translation, restCoordinate: 0, maximumRate: 5, displacements: [-1,0,0], restoringEfforts: [-1,0,1], maximumKnots: 3, work: &work)
        }
        #expect(throws: LoadError.invalidPassiveLaw) {
            try TabulatedSpringLaw(coordinateKind: .translation, restCoordinate: 0, maximumRate: 5, displacements: [-1,0,1], restoringEfforts: [-1,0,-2], maximumKnots: 3, work: &work)
        }
        #expect(throws: LoadError.outsideDomain) { try evaluate(2.01) }
        #expect(throws: LoadError.invalidInput) { try evaluate(.nan) }
        #expect(throws: LoadError.nonFiniteResult) {
            try TabulatedSpringLaw(coordinateKind: .translation, restCoordinate: 0, maximumRate: 5, displacements: [0,1e-308,1], restoringEfforts: [0,1e308,1e308], maximumKnots: 3, work: &work)

        }
    }
    @Test func boundedConstructionAndQueryPreserveLaw() throws {
        let p = try law(), original = p
        var small = try NineServiceFixture.work(maximumScalars: 0)
        #expect(throws: LoadError.capacityExceeded) {
            try TabulatedSpringLaw(coordinateKind: .translation, restCoordinate: 0, maximumRate: 5, displacements: [-1,0,1], restoringEfforts: [-1,0,1], maximumKnots: 3, work: &small)
        }
        var exhausted = try NineServiceFixture.work(maximumWork: 0)
        #expect(throws: LoadError.workExhausted) { try service.evaluate(law: p, coordinate: 0.5, rate: 0, work: &exhausted) }
        var cancelled = try NineServiceFixture.work(cancelled: true)
        #expect(throws: LoadError.cancelled) { try service.evaluate(law: p, coordinate: 0.5, rate: 0, work: &cancelled) }
        #expect(p == original)
    }
    @Test func tinySignedSamplesPreserveOriginalCalibration() throws {
        let negative = try evaluate(-1e-20), positive = try evaluate(1e-20)
        #expect(NineServiceFixture.near(negative.effort, 2e-20, absolute: 1e-32))
        #expect(NineServiceFixture.near(positive.effort, -3e-20, absolute: 1e-32))
        #expect(NineServiceFixture.near(negative.potentialEnergy, 1e-40, absolute: 1e-52))
    }
}
