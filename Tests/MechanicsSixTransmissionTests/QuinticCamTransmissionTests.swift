import SwiftMechanics
import Testing
import Darwin

@Suite(.timeLimit(.minutes(1))) struct QuinticCamTransmissionTests {
    func law() throws -> any NonlinearTransmissionEvaluating {
        try QuinticCamTransmission(lift: 0.03,startAngle: 0.2,riseAngle: 1.7,outputOffset: 0.4)
    }
    @Test func independentOriginalGeometryAndDerivatives() throws {
        let r=try law().evaluate(inputCoordinate: 0.2+1.7/4)
        #expect(NonlinearTransmissionFixture.near(r.outputCoordinate,0.4+0.03*0.103515625))
        #expect(NonlinearTransmissionFixture.near(r.derivative,(0.03/1.7)*30*pow(0.25,2)*pow(0.75,2)))
        let expectedCurvature: Double = (0.03/(1.7*1.7))*5.625
        #expect(NonlinearTransmissionFixture.near(r.curvature,expectedCurvature))
        #expect(r.inputKind == .rotation && r.outputKind == .translation)
    }
    @Test func firstAndSecondDerivativeRefinement() throws { try NonlinearTransmissionFixture.derivatives(law(),at: 0.8) }
    @Test func originalAccelerationConjugatePowerAndLocalInverse() throws { try NonlinearTransmissionFixture.originalMotionAndPower(law(),at: 0.8) }
    @Test func actualExistingActuationSupplierMapping() throws { try NonlinearTransmissionFixture.actualAffine(law(),at: 0.8) }
    @Test func explicitAssemblyPhaseOrEndpointBranches() throws {
        let model=try QuinticCamTransmission(lift: 0.03,startAngle: 0.2,riseAngle: 1.7,outputOffset: 0.4)
        let a=try model.evaluate(inputCoordinate: model.inputDomain.minimum), b=try model.evaluate(inputCoordinate: model.inputDomain.maximum)
        #expect(a.outputCoordinate == 0.4 && NonlinearTransmissionFixture.near(b.outputCoordinate,0.43))
        #expect(a.derivative == 0 && a.curvature == 0 && b.derivative == 0 && b.curvature == 0)
        let left=try model.evaluate(inputCoordinate: 0.2+1.7*0.25), right=try model.evaluate(inputCoordinate: 0.2+1.7*0.75)
        #expect(NonlinearTransmissionFixture.near(left.outputCoordinate+right.outputCoordinate,0.83))
        #expect(NonlinearTransmissionFixture.near(left.derivative,right.derivative) && NonlinearTransmissionFixture.near(left.curvature,-right.curvature))
    }
    @Test func tinyProfileOrUnwrappedTurns() throws {
        let model=try QuinticCamTransmission(lift: 0.03,riseAngle: 1.7)
        let u=1e-10, r=try model.evaluate(inputCoordinate: 1.7*u)
        #expect(r.outputCoordinate > 0)
        #expect(NonlinearTransmissionFixture.near(r.outputCoordinate,0.3*u*u*u,absolute: 1e-40,relative: 1e-7))
        #expect(NonlinearTransmissionFixture.near(r.derivative,(0.03/1.7)*30*u*u,absolute: 1e-30,relative: 1e-7))
    }
    @Test func parameterQueryFailuresPreserveOriginalSample() throws {
        #expect(throws: NonlinearTransmissionError.self) { try QuinticCamTransmission(lift: 0.03,riseAngle: -1) }
        try NonlinearTransmissionFixture.queryRefusals(law(),at: 0.8,minimum: 0.2,maximum: 0.2+1.7)
    }
}
