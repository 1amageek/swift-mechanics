import SwiftMechanics
import Testing
import Darwin

@Suite(.timeLimit(.minutes(1))) struct HarmonicCamTransmissionTests {
    func law() throws -> any NonlinearTransmissionEvaluating {
        try HarmonicCamTransmission(lift: 0.03,inputPhase: 0.2,outputOffset: 0.4,inputDomain: NonlinearTransmissionFixture.domain())
    }
    @Test func independentOriginalGeometryAndDerivatives() throws {
        let r=try law().evaluate(inputCoordinate: 0.2+Double.pi/2)
        #expect(NonlinearTransmissionFixture.near(r.outputCoordinate,0.415))
        #expect(NonlinearTransmissionFixture.near(r.derivative,0.015) && abs(r.curvature) < 1e-14)
        #expect(r.inputKind == .rotation && r.outputKind == .translation)
    }
    @Test func firstAndSecondDerivativeRefinement() throws { try NonlinearTransmissionFixture.derivatives(law(),at: 0.8) }
    @Test func originalAccelerationConjugatePowerAndLocalInverse() throws { try NonlinearTransmissionFixture.originalMotionAndPower(law(),at: 0.8) }
    @Test func actualExistingActuationSupplierMapping() throws { try NonlinearTransmissionFixture.actualAffine(law(),at: 0.8) }
    @Test func explicitAssemblyPhaseOrEndpointBranches() throws {
        let a=try law().evaluate(inputCoordinate: 0.2), b=try law().evaluate(inputCoordinate: 0.2+Double.pi)
        #expect(a.outputCoordinate == 0.4 && a.derivative == 0 && a.curvature == 0.015)
        #expect(NonlinearTransmissionFixture.near(b.outputCoordinate,0.43) && NonlinearTransmissionFixture.near(b.curvature,-0.015))
        #expect(throws: NonlinearTransmissionError.self) { try b.inputRate(forOutputRate: 0,minimumAbsoluteDerivative: 1e-12) }
    }
    @Test func tinyProfileOrUnwrappedTurns() throws {
        let a=try law().evaluate(inputCoordinate: 0.8), b=try law().evaluate(inputCoordinate: 0.8+12*Double.pi)
        #expect(NonlinearTransmissionFixture.near(a.outputCoordinate,b.outputCoordinate) && NonlinearTransmissionFixture.near(a.derivative,b.derivative))
        let tiny=try HarmonicCamTransmission(lift: 0.03,inputDomain: NonlinearTransmissionFixture.domain()).evaluate(inputCoordinate: 1e-10)
        #expect(NonlinearTransmissionFixture.near(tiny.outputCoordinate,7.5e-23,absolute: 1e-35))
    }
    @Test func parameterQueryFailuresPreserveOriginalSample() throws {
        #expect(throws: NonlinearTransmissionError.self) { try HarmonicCamTransmission(lift: 0,inputDomain: NonlinearTransmissionFixture.domain()) }
        try NonlinearTransmissionFixture.queryRefusals(law(),at: 0.8,minimum: -20*Double.pi,maximum: 20*Double.pi)
    }
}
