import SwiftMechanics
import Testing
import Darwin

@Suite(.timeLimit(.minutes(1))) struct VariableLeadScrewTransmissionTests {
    func law() throws -> any NonlinearTransmissionEvaluating {
        try VariableLeadScrewTransmission(leadAtPhase: 0.002,leadSlope: 0.0001,inputPhase: 0.1,outputOffset: 0.3,
            inputDomain: TransmissionInputDomain(minimum: -4,maximum: 4))
    }
    @Test func independentOriginalGeometryAndDerivatives() throws {
        let r=try law().evaluate(inputCoordinate: 0.8)
        #expect(NonlinearTransmissionFixture.near(r.outputCoordinate,0.3014245))
        #expect(NonlinearTransmissionFixture.near(r.derivative,0.00207) && r.curvature == 0.0001)
        #expect(r.inputKind == .rotation && r.outputKind == .translation)
    }
    @Test func firstAndSecondDerivativeRefinement() throws { try NonlinearTransmissionFixture.derivatives(law(),at: 0.8) }
    @Test func originalAccelerationConjugatePowerAndLocalInverse() throws { try NonlinearTransmissionFixture.originalMotionAndPower(law(),at: 0.8) }
    @Test func actualExistingActuationSupplierMapping() throws { try NonlinearTransmissionFixture.actualAffine(law(),at: 0.8) }
    @Test func explicitAssemblyPhaseOrEndpointBranches() throws {
        let d=try TransmissionInputDomain(minimum: -4,maximum: 4)
        let reverse=try VariableLeadScrewTransmission(leadAtPhase: -0.002,leadSlope: -0.0001,inputDomain: d)
        let r=try reverse.evaluate(inputCoordinate: 0.7)
        #expect(NonlinearTransmissionFixture.near(r.outputCoordinate,-0.0014245) && NonlinearTransmissionFixture.near(r.derivative,-0.00207))
        #expect(throws: NonlinearTransmissionError.invalidParameter(name: "signedLeadDomain")) { try VariableLeadScrewTransmission(leadAtPhase: 0.0001,leadSlope: 0.001,inputDomain: d) }
        #expect(throws: NonlinearTransmissionError.self) { try VariableLeadScrewTransmission(leadAtPhase: 0,leadSlope: 0,inputDomain: d) }
    }
    @Test func tinyProfileOrUnwrappedTurns() throws {
        let constant=try VariableLeadScrewTransmission(leadAtPhase: -0.002,leadSlope: 0,inputDomain: NonlinearTransmissionFixture.domain())
        let r=try constant.evaluate(inputCoordinate: 2*Double.pi)
        #expect(NonlinearTransmissionFixture.near(r.outputCoordinate,-0.004*Double.pi) && r.curvature == 0)
        let tiny=try constant.evaluate(inputCoordinate: 1e-20)
        #expect(NonlinearTransmissionFixture.near(tiny.outputCoordinate,-2e-23,absolute: 1e-35))
    }
    @Test func parameterQueryFailuresPreserveOriginalSample() throws {
        #expect(throws: NonlinearTransmissionError.self) { try VariableLeadScrewTransmission(leadAtPhase: .nan,leadSlope: 0,inputDomain: NonlinearTransmissionFixture.domain()) }
        try NonlinearTransmissionFixture.queryRefusals(law(),at: 0.8,minimum: -4,maximum: 4)
    }
}
