import SwiftMechanics
import Testing
import Darwin

@Suite(.timeLimit(.minutes(1))) struct SliderCrankTransmissionTests {
    func law() throws -> any NonlinearTransmissionEvaluating {
        try SliderCrankTransmission(crankRadius: 0.04,rodLength: 0.2,sliderOffset: 0.01,inputPhase: 0.1,
            outputOffset: 0.3,assembly: .positiveRodProjection,inputDomain: NonlinearTransmissionFixture.domain())
    }
    @Test func independentOriginalGeometryAndDerivatives() throws {
        let r=try law().evaluate(inputCoordinate: 0.1), rod=sqrt(0.2*0.2-0.01*0.01)
        #expect(NonlinearTransmissionFixture.near(r.outputCoordinate,0.34+rod))
        #expect(NonlinearTransmissionFixture.near(r.derivative,0.04*0.01/rod))
        #expect(NonlinearTransmissionFixture.near(r.curvature,-0.04-pow(0.04,2)*pow(0.2,2)/pow(rod,3)))
        #expect(r.inputKind == .rotation && r.outputKind == .translation)
    }
    @Test func firstAndSecondDerivativeRefinement() throws { try NonlinearTransmissionFixture.derivatives(law(),at: 0.8) }
    @Test func originalAccelerationConjugatePowerAndLocalInverse() throws { try NonlinearTransmissionFixture.originalMotionAndPower(law(),at: 0.8) }
    @Test func actualExistingActuationSupplierMapping() throws { try NonlinearTransmissionFixture.actualAffine(law(),at: 0.8) }
    @Test func explicitAssemblyPhaseOrEndpointBranches() throws {
        let domain=try NonlinearTransmissionFixture.domain()
        let positive=try SliderCrankTransmission(crankRadius: 0.04,rodLength: 0.2,assembly: .positiveRodProjection,inputDomain: domain)
        let negative=try SliderCrankTransmission(crankRadius: 0.04,rodLength: 0.2,assembly: .negativeRodProjection,inputDomain: domain)
        let p=try positive.evaluate(inputCoordinate: 0), n=try negative.evaluate(inputCoordinate: 0)
        #expect(NonlinearTransmissionFixture.near(p.outputCoordinate,0.24) && NonlinearTransmissionFixture.near(n.outputCoordinate,-0.16))
        #expect(p.derivative == 0 && n.derivative == 0)
        #expect(NonlinearTransmissionFixture.near(p.curvature,-0.048) && NonlinearTransmissionFixture.near(n.curvature,-0.032))
        let impossible=try SliderCrankTransmission(crankRadius: 0.04,rodLength: 0.04,sliderOffset: 0.05,assembly: .positiveRodProjection,inputDomain: domain)
        #expect(throws: NonlinearTransmissionError.impossibleClosure) { try impossible.evaluate(inputCoordinate: 0) }
        let singular=try SliderCrankTransmission(crankRadius: 0.04,rodLength: 0.04,sliderOffset: 0.04,assembly: .positiveRodProjection,inputDomain: domain)
        #expect(throws: NonlinearTransmissionError.singularClosure) { try singular.evaluate(inputCoordinate: 0) }
    }
    @Test func tinyProfileOrUnwrappedTurns() throws {
        let a=try law().evaluate(inputCoordinate: 0.8), b=try law().evaluate(inputCoordinate: 0.8+2*Double.pi)
        #expect(NonlinearTransmissionFixture.near(a.outputCoordinate,b.outputCoordinate))
        #expect(NonlinearTransmissionFixture.near(a.derivative,b.derivative))
    }
    @Test func parameterQueryFailuresPreserveOriginalSample() throws {
        #expect(throws: NonlinearTransmissionError.self) { try SliderCrankTransmission(crankRadius: 0.04,rodLength: 0,assembly: .positiveRodProjection,inputDomain: NonlinearTransmissionFixture.domain()) }
        try NonlinearTransmissionFixture.queryRefusals(law(),at: 0.8,minimum: -20*Double.pi,maximum: 20*Double.pi)
    }
}
