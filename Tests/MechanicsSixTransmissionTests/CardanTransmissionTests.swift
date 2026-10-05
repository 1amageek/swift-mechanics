import SwiftMechanics
import Testing
import Darwin

@Suite(.timeLimit(.minutes(1))) struct CardanTransmissionTests {
    func law() throws -> any NonlinearTransmissionEvaluating {
        try CardanTransmission(shaftAngle: Double.pi/6,inputPhase: 0.2,outputPhase: -0.4,inputDomain: NonlinearTransmissionFixture.domain())
    }
    @Test func independentOriginalGeometryAndDerivatives() throws {
        let q=0.2+Double.pi/4, r=try law().evaluate(inputCoordinate: q), c=sqrt(0.75), denominator=0.875
        #expect(NonlinearTransmissionFixture.near(r.outputCoordinate,-0.4+atan(c)))
        #expect(NonlinearTransmissionFixture.near(r.derivative,c/denominator))
        #expect(NonlinearTransmissionFixture.near(r.curvature,c*0.25/(denominator*denominator)))
        #expect(r.inputKind == .rotation && r.outputKind == .rotation)
    }
    @Test func firstAndSecondDerivativeRefinement() throws { try NonlinearTransmissionFixture.derivatives(law(),at: 0.8) }
    @Test func originalAccelerationConjugatePowerAndLocalInverse() throws { try NonlinearTransmissionFixture.originalMotionAndPower(law(),at: 0.8) }
    @Test func actualExistingActuationSupplierMapping() throws { try NonlinearTransmissionFixture.actualAffine(law(),at: 0.8) }
    @Test func explicitAssemblyPhaseOrEndpointBranches() throws {
        let c=cos(Double.pi/6), a=try law().evaluate(inputCoordinate: 0.2), b=try law().evaluate(inputCoordinate: 0.2+Double.pi/2)
        #expect(NonlinearTransmissionFixture.near(a.derivative,c) && NonlinearTransmissionFixture.near(b.derivative,1/c))
        let aligned=try CardanTransmission(shaftAngle: 0,inputDomain: NonlinearTransmissionFixture.domain())
        let r=try aligned.evaluate(inputCoordinate: -3.2)
        #expect(r.outputCoordinate == -3.2 && r.derivative == 1 && r.curvature == 0)
    }
    @Test func tinyProfileOrUnwrappedTurns() throws {
        let a=try law().evaluate(inputCoordinate: 0.8)
        for turns in [-7.0,7.0] {
            let b=try law().evaluate(inputCoordinate: 0.8+turns*2*Double.pi)
            #expect(NonlinearTransmissionFixture.near(b.outputCoordinate-a.outputCoordinate,turns*2*Double.pi))
            #expect(NonlinearTransmissionFixture.near(a.derivative,b.derivative))
        }
        let left=try law().evaluate(inputCoordinate: 0.2+Double.pi-1e-8), right=try law().evaluate(inputCoordinate: 0.2+Double.pi+1e-8)
        #expect(abs(right.outputCoordinate-left.outputCoordinate) < 3e-8)
    }
    @Test func parameterQueryFailuresPreserveOriginalSample() throws {
        #expect(throws: NonlinearTransmissionError.self) { try CardanTransmission(shaftAngle: Double.pi/2,inputDomain: NonlinearTransmissionFixture.domain()) }
        try NonlinearTransmissionFixture.queryRefusals(law(),at: 0.8,minimum: -20*Double.pi,maximum: 20*Double.pi)
    }
}
