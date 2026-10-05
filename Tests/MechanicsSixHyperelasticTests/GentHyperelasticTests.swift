import Testing
import SwiftMechanics
import Darwin

@Suite(.timeLimit(.minutes(1))) struct GentHyperelasticTests {
    func law() throws -> any HyperelasticResponding {
        try GentHyperelasticity(shearModulus: 20, lockingInvariant: 2, bulkModulus: 100, domain: HyperelasticFixture.domain())
    }
    @Test func independentSimpleShearAndRecovery() throws {
        try HyperelasticFixture.shearOracle(law(), expectedEnergy: -20*log(0.98), expectedDerivative: 10/0.98)
    }
    @Test func independentHydrostaticStretch() throws {
        let j=1.1*1.1*1.1
        try HyperelasticFixture.volumeOracle(law(), expectedEnergy: 50*(j-1)*(j-1), expectedPressure: 100*(j-1))
    }
    @Test func independentAnisotropicStretch() throws {
        // Reference values evaluated from original invariants with 70-digit decimal arithmetic.
        let r=try law().evaluate(deformationGradient: HyperelasticFixture.diagonal(1.2,0.8,1.05))
        #expect(HyperelasticFixture.near(r.energyDensity, 1.7322200269618448))
        let expected=try HyperelasticFixture.diagonal(7.5255734527403693,-10.402070088902923,1.6287313598418045)
        #expect(try HyperelasticFixture.matrixNear(r.firstPiolaStress,expected))
    }
    @Test func allStressTangentsAndPotentialDerivative() throws { try HyperelasticFixture.tangentOracle(law()) }
    @Test func rigidRotationAndDirectionalObjectivity() throws { try HyperelasticFixture.objectivityOracle(law()) }
    @Test func tinyShearRetainsOriginalPositiveEnergy() throws {
        let response=try law().evaluate(deformationGradient: HyperelasticFixture.shear(1e-20))
        #expect(HyperelasticFixture.near(response.energyDensity, 1e-39, absolute: 1e-50))
    }
    @Test func calibratedParameterDomainAndArithmeticRefusal() throws {
        #expect(throws: MaterialError.self) { try GentHyperelasticity(shearModulus: 20, lockingInvariant: 0, bulkModulus: 100, domain: HyperelasticFixture.domain()) }
        try HyperelasticFixture.failureOracle(law())
        let locked=try GentHyperelasticity(shearModulus: 20, lockingInvariant: 0.25, bulkModulus: 100, domain: HyperelasticFixture.domain())
        #expect(throws: MaterialError.self) { try locked.evaluate(deformationGradient: HyperelasticFixture.shear(0.5)) }
        #expect(throws: MaterialError.self) { try locked.evaluate(deformationGradient: HyperelasticFixture.shear(0.6)) }
        #expect(try locked.evaluate(deformationGradient: HyperelasticFixture.shear(0.49)).energyDensity > 0)
    }
}
