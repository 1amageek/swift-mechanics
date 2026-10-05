import Testing
import SwiftMechanics
import Darwin

@Suite(.timeLimit(.minutes(1))) struct ArrudaBoyceHyperelasticTests {
    func law() throws -> any HyperelasticResponding {
        try ArrudaBoyceHyperelasticity(chainModulus: 20, chainSegments: 10, bulkModulus: 100, domain: HyperelasticFixture.domain())
    }
    @Test func independentSimpleShearAndRecovery() throws {
        try HyperelasticFixture.shearOracle(law(), expectedEnergy: arrudaEnergy(0.04), expectedDerivative: arrudaDerivative(0.04))
    }
    @Test func independentHydrostaticStretch() throws {
        let j=1.1*1.1*1.1
        try HyperelasticFixture.volumeOracle(law(), expectedEnergy: 50*(j-1)*(j-1), expectedPressure: 100*(j-1))
    }
    @Test func independentAnisotropicStretch() throws {
        // Reference values evaluated from original invariants with 70-digit decimal arithmetic.
        let r=try law().evaluate(deformationGradient: HyperelasticFixture.diagonal(1.2,0.8,1.05))
        #expect(HyperelasticFixture.near(r.energyDensity, 1.7727845633431698))
        let expected=try HyperelasticFixture.diagonal(7.400357927098085,-10.193606878630328,1.6130057051300577)
        #expect(try HyperelasticFixture.matrixNear(r.firstPiolaStress,expected))
    }
    @Test func allStressTangentsAndPotentialDerivative() throws { try HyperelasticFixture.tangentOracle(law()) }
    @Test func rigidRotationAndDirectionalObjectivity() throws { try HyperelasticFixture.objectivityOracle(law()) }
    @Test func tinyShearRetainsOriginalPositiveEnergy() throws {
        let response=try law().evaluate(deformationGradient: HyperelasticFixture.shear(1e-20))
        #expect(HyperelasticFixture.near(response.energyDensity, 2e-39*arrudaDerivative(0)/20, absolute: 1e-50))
    }
    @Test func calibratedParameterDomainAndArithmeticRefusal() throws {
        #expect(throws: MaterialError.self) { try ArrudaBoyceHyperelasticity(chainModulus: 20, chainSegments: 1, bulkModulus: 100, domain: HyperelasticFixture.domain()) }
        try HyperelasticFixture.failureOracle(law())
        let locked=try ArrudaBoyceHyperelasticity(chainModulus: 20, chainSegments: 2, bulkModulus: 100, domain: HyperelasticFixture.domain())
        #expect(throws: MaterialError.self) { try locked.evaluate(deformationGradient: HyperelasticFixture.shear(2)) }
        #expect(try locked.evaluate(deformationGradient: HyperelasticFixture.shear(1)).energyDensity > 0)
    }
    func arrudaEnergy(_ x: Double) -> Double {
        let coefficients=[0.5,1.0/20,11.0/1050,19.0/7000,519.0/673750]
        var sum=0.0
        for p in 1...5 {
            let difference=pow(3+x,Double(p))-pow(3,Double(p))
            let scale=coefficients[p-1]/pow(10,Double(p-1))
            sum += scale*difference
        }
        return 20*sum
    }
    func arrudaDerivative(_ x: Double) -> Double {
        let coefficients=[0.5,1.0/20,11.0/1050,19.0/7000,519.0/673750]
        var sum=0.0
        for p in 1...5 {
            let power=pow(3+x,Double(p-1))
            let scale=Double(p)*coefficients[p-1]/pow(10,Double(p-1))
            sum += scale*power
        }
        return 20*sum
    }
}
