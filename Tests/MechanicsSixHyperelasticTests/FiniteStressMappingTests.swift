import Testing
import SwiftMechanics

@Suite(.timeLimit(.minutes(1))) struct FiniteStressMappingTests {
    @Test func originalPublicStressAndVolumeDirectionMapping() throws {
        let f=try HyperelasticFixture.diagonal(1.2,0.9,1.1)
        let k=try FiniteStrainKinematics(deformationGradient: f,domain: HyperelasticFixture.domain())
        let s=try SymmetricTensor(xx: 3,yy: 4,zz: 5), ds=try SymmetricTensor(xx: 2,yy: -1,zz: 0.5)
        let h=try HyperelasticFixture.diagonal(0.1,-0.2,0.3)
        let r=try k.response(secondPiolaStress: s,energyDensity: 10)
        #expect(try HyperelasticFixture.matrixNear(r.firstPiolaStress,HyperelasticFixture.diagonal(3.6,3.6,5.5)))
        let j=1.2*0.9*1.1, relativeJ=0.1/1.2-0.2/0.9+0.3/1.1
        let tangent=try k.directionalResponse(deformationDirection: h,secondPiolaStress: s,secondPiolaDirection: ds)
        #expect(try HyperelasticFixture.matrixNear(tangent.firstPiolaDirection,HyperelasticFixture.diagonal(2.7,-1.7,2.05)))
        let expected=try HyperelasticFixture.diagonal((2*1.2*0.1*3+1.2*1.2*2-1.2*1.2*3*relativeJ)/j,
            (2*0.9*(-0.2)*4-0.9*0.9-0.9*0.9*4*relativeJ)/j,
            (2*1.1*0.3*5+1.1*1.1*0.5-1.1*1.1*5*relativeJ)/j)
        #expect(try HyperelasticFixture.matrixNear(tangent.cauchyDirection,expected))
    }
    @Test func energyAndOverflowFailuresRemainExplicit() throws {
        let k=try FiniteStrainKinematics(deformationGradient: .identity,domain: HyperelasticFixture.domain())
        #expect(throws: MaterialError.invalidParameter(name: "finiteStressEnergy")) { try k.response(secondPiolaStress: .zero,energyDensity: -1) }
        #expect(throws: MaterialError.self) { try k.response(secondPiolaStress: .zero,energyDensity: .nan) }
        let large=try SymmetricTensor(xx: 1e308,yy: 1e308,zz: 1e308)
        #expect(throws: MaterialError.self) { try k.directionalResponse(deformationDirection: HyperelasticFixture.diagonal(2,2,2),secondPiolaStress: large,secondPiolaDirection: large) }
        #expect(try k.response(secondPiolaStress: .zero,energyDensity: 0).energyDensity == 0)
    }
}
