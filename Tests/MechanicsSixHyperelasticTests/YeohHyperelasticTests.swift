import Testing
import SwiftMechanics
import Darwin

@Suite(.timeLimit(.minutes(1))) struct YeohHyperelasticTests {
    func law() throws -> any HyperelasticResponding {
        try YeohHyperelasticity(c1: 10, c2: 2, c3: 3, bulkModulus: 100, domain: HyperelasticFixture.domain())
    }
    @Test func independentSimpleShearAndRecovery() throws {
        try HyperelasticFixture.shearOracle(law(), expectedEnergy: 10*0.04+2*0.04*0.04+3*pow(0.04,3), expectedDerivative: 10+4*0.04+9*0.04*0.04)
    }
    @Test func independentHydrostaticStretch() throws {
        let j=1.1*1.1*1.1
        try HyperelasticFixture.volumeOracle(law(), expectedEnergy: 50*(j-1)*(j-1), expectedPressure: 100*(j-1))
    }
    @Test func independentAnisotropicStretch() throws {
        // Reference values evaluated from original invariants with 70-digit decimal arithmetic.
        let r=try law().evaluate(deformationGradient: HyperelasticFixture.diagonal(1.2,0.8,1.05))
        #expect(HyperelasticFixture.near(r.energyDensity, 1.7280963652305232))
        let expected=try HyperelasticFixture.diagonal(7.5296613631165341,-10.408875785847856,1.6292447551794706)
        #expect(try HyperelasticFixture.matrixNear(r.firstPiolaStress,expected))
    }
    @Test func allStressTangentsAndPotentialDerivative() throws { try HyperelasticFixture.tangentOracle(law()) }
    @Test func rigidRotationAndDirectionalObjectivity() throws { try HyperelasticFixture.objectivityOracle(law()) }
    @Test func tinyShearRetainsOriginalPositiveEnergy() throws {
        let response=try law().evaluate(deformationGradient: HyperelasticFixture.shear(1e-20))
        #expect(HyperelasticFixture.near(response.energyDensity, 1e-39, absolute: 1e-50))
    }
    @Test func calibratedParameterDomainAndArithmeticRefusal() throws {
        #expect(throws: MaterialError.self) { try YeohHyperelasticity(c1: 10, c2: -2, c3: 3, bulkModulus: 100, domain: HyperelasticFixture.domain()) }
        try HyperelasticFixture.failureOracle(law())

    }
}
