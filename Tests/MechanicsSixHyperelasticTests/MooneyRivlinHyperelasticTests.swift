import Testing
import SwiftMechanics
import Darwin

@Suite(.timeLimit(.minutes(1))) struct MooneyRivlinHyperelasticTests {
    func law() throws -> any HyperelasticResponding {
        try MooneyRivlinHyperelasticity(c1: 6, c2: 4, bulkModulus: 100, domain: HyperelasticFixture.domain())
    }
    @Test func independentSimpleShearAndRecovery() throws {
        try HyperelasticFixture.shearOracle(law(), expectedEnergy: 0.4, expectedDerivative: 10)
    }
    @Test func independentHydrostaticStretch() throws {
        let j=1.1*1.1*1.1
        try HyperelasticFixture.volumeOracle(law(), expectedEnergy: 50*(j-1)*(j-1), expectedPressure: 100*(j-1))
    }
    @Test func independentAnisotropicStretch() throws {
        // Reference values evaluated from original invariants with 70-digit decimal arithmetic.
        let r=try law().evaluate(deformationGradient: HyperelasticFixture.diagonal(1.2,0.8,1.05))
        #expect(HyperelasticFixture.near(r.energyDensity, 1.7203382634961286))
        let expected=try HyperelasticFixture.diagonal(6.8577924157490244,-10.376525372970772,2.3724470471217018)
        #expect(try HyperelasticFixture.matrixNear(r.firstPiolaStress,expected))
    }
    @Test func allStressTangentsAndPotentialDerivative() throws { try HyperelasticFixture.tangentOracle(law()) }
    @Test func rigidRotationAndDirectionalObjectivity() throws { try HyperelasticFixture.objectivityOracle(law()) }
    @Test func tinyShearRetainsOriginalPositiveEnergy() throws {
        let response=try law().evaluate(deformationGradient: HyperelasticFixture.shear(1e-20))
        #expect(HyperelasticFixture.near(response.energyDensity, 1e-39, absolute: 1e-50))
    }
    @Test func calibratedParameterDomainAndArithmeticRefusal() throws {
        #expect(throws: MaterialError.self) { try MooneyRivlinHyperelasticity(c1: -1, c2: 4, bulkModulus: 100, domain: HyperelasticFixture.domain()) }
        try HyperelasticFixture.failureOracle(law())

    }
}
