import Testing
import SwiftMechanics
import Darwin

@Suite(.timeLimit(.minutes(1))) struct BlatzKoHyperelasticTests {
    func law() throws -> any HyperelasticResponding {
        try BlatzKoHyperelasticity(shearModulus: 20, domain: HyperelasticFixture.domain())
    }
    @Test func independentSimpleShearAndRecovery() throws {
        try HyperelasticFixture.shearOracle(law(), expectedEnergy: 0.4, expectedDerivative: 10)
    }
    @Test func independentHydrostaticStretch() throws {
        let s=1.1
        try HyperelasticFixture.volumeOracle(law(), expectedEnergy: 10*(3/(s*s)+2*s*s*s-5), expectedPressure: 20*(1-pow(s,-5)))
    }
    @Test func independentAnisotropicStretch() throws {
        // Reference values evaluated from original invariants with 70-digit decimal arithmetic.
        let r=try law().evaluate(deformationGradient: HyperelasticFixture.diagonal(1.2,0.8,1.05))
        #expect(HyperelasticFixture.near(r.energyDensity, 1.7997392290249432))
        let expected=try HyperelasticFixture.diagonal(5.2259259259259263,-13.862500000000001,1.9232480293704783)
        #expect(try HyperelasticFixture.matrixNear(r.firstPiolaStress,expected))
    }
    @Test func allStressTangentsAndPotentialDerivative() throws { try HyperelasticFixture.tangentOracle(law()) }
    @Test func rigidRotationAndDirectionalObjectivity() throws { try HyperelasticFixture.objectivityOracle(law()) }
    @Test func tinyShearRetainsOriginalPositiveEnergy() throws {
        let response=try law().evaluate(deformationGradient: HyperelasticFixture.shear(1e-20))
        #expect(HyperelasticFixture.near(response.energyDensity, 1e-39, absolute: 1e-50))
    }
    @Test func calibratedParameterDomainAndArithmeticRefusal() throws {
        #expect(throws: MaterialError.self) { try BlatzKoHyperelasticity(shearModulus: 0, domain: HyperelasticFixture.domain()) }
        try HyperelasticFixture.failureOracle(law())

    }
}
