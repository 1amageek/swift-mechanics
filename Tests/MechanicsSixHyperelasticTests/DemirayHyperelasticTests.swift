import Testing
import SwiftMechanics
import Darwin

@Suite(.timeLimit(.minutes(1))) struct DemirayHyperelasticTests {
    func law() throws -> any HyperelasticResponding {
        try DemirayHyperelasticity(shearModulus: 20, stiffening: 2, bulkModulus: 100, domain: HyperelasticFixture.domain())
    }
    @Test func independentSimpleShearAndRecovery() throws {
        try HyperelasticFixture.shearOracle(law(), expectedEnergy: 5*expm1(0.08), expectedDerivative: 10*exp(0.08))
    }
    @Test func independentHydrostaticStretch() throws {
        let j=1.1*1.1*1.1
        try HyperelasticFixture.volumeOracle(law(), expectedEnergy: 50*(j-1)*(j-1), expectedPressure: 100*(j-1))
    }
    @Test func independentAnisotropicStretch() throws {
        // Reference values evaluated from original invariants with 70-digit decimal arithmetic.
        let r=try law().evaluate(deformationGradient: HyperelasticFixture.diagonal(1.2,0.8,1.05))
        #expect(HyperelasticFixture.near(r.energyDensity, 1.9669349368431961))
        let expected=try HyperelasticFixture.diagonal(9.4267572091187777,-13.567227661335108,1.8674985505957649)
        #expect(try HyperelasticFixture.matrixNear(r.firstPiolaStress,expected))
    }
    @Test func allStressTangentsAndPotentialDerivative() throws { try HyperelasticFixture.tangentOracle(law()) }
    @Test func rigidRotationAndDirectionalObjectivity() throws { try HyperelasticFixture.objectivityOracle(law()) }
    @Test func tinyShearRetainsOriginalPositiveEnergy() throws {
        let response=try law().evaluate(deformationGradient: HyperelasticFixture.shear(1e-20))
        #expect(HyperelasticFixture.near(response.energyDensity, 1e-39, absolute: 1e-50))
    }
    @Test func calibratedParameterDomainAndArithmeticRefusal() throws {
        #expect(throws: MaterialError.self) { try DemirayHyperelasticity(shearModulus: 20, stiffening: 0, bulkModulus: 100, domain: HyperelasticFixture.domain()) }
        try HyperelasticFixture.failureOracle(law())
        let overflow=try DemirayHyperelasticity(shearModulus: 20, stiffening: 1e308, bulkModulus: 100, domain: HyperelasticFixture.domain())
        #expect(throws: MaterialError.self) { try overflow.evaluate(deformationGradient: HyperelasticFixture.shear(0.2)) }
    }
}
