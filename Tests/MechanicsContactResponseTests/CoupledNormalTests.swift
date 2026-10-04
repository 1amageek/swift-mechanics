import SwiftMechanics
import Testing
@Suite(.timeLimit(.minutes(1)))
struct CoupledNormalTests {
    @Test func singleEffectiveMassAndOriginalNormalMomentum() throws {
        let input=try ResponseFixtures.input(), result=try ResponseFixtures.solve(input)
        let force=0.1/(0.001+0.01/2)
        #expect(ResponseFixtures.close(result.effectiveMassInverse[0],0.5))
        #expect(ResponseFixtures.close(result.observations[0].normalForce,force))
        #expect(ResponseFixtures.close(result.endpointVelocity[0],0.1*force/2))
        #expect(ResponseFixtures.close(result.observations[0].trialSeparation,-force/1000))
        #expect(ResponseFixtures.close(result.generalizedContactForce[0],force))
        #expect(result.originalPhysicalResidual.isAccepted && result.numericalDiagnostics.originalResidual.isAccepted)
        #expect(result.effectiveMassRank == nil && result.uniqueCompliantForce)
        #expect(result.observations[0].lawResponse.frictionRegime == .disabled)
        #expect(result.observations[0].intervalStart == 0 && result.observations[0].intervalEnd == 0.1)
        #expect(ResponseFixtures.close(result.observations[0].equivalentImpulseOnB.z,0.1*force))
        #expect(input.contacts[0].accepted.sequence == 0 && result.observations[0].lawResponse.trialHistory.sequence == 1)
    }
    @Test func coupledTwoBodyStackRetainsGravityAndOffDiagonalMass() throws {
        let input=try ResponseFixtures.input(stack:true,gravity:true), result=try ResponseFixtures.solve(input)
        let a=0.001+0.01/2,b = -0.01/2,d=0.001+0.01*(5.0/6), determinant=a*d-b*b
        let first=(0.2*d-b*0.1)/determinant, second=(a*0.1-b*0.2)/determinant
        #expect(ResponseFixtures.close(result.observations[0].normalForce,first))
        #expect(ResponseFixtures.close(result.observations[1].normalForce,second))
        let expected=[0.5,-0.5,-0.5,5.0/6]
        for i in 0..<4 { #expect(ResponseFixtures.close(result.effectiveMassInverse[i],expected[i])) }
        #expect(ResponseFixtures.close(2*result.endpointVelocity[0],0.1*(first-second-20)))
        let upperVelocity=result.endpointVelocity[0]+result.endpointVelocity[1]
        #expect(ResponseFixtures.close(3*upperVelocity,0.1*(second-30)))
        #expect(result.originalPhysicalResidual.isAccepted)
        #expect(result.dynamicsWork.iterations >= 6 && result.coneWork.iterations > 0)
    }
    @Test func dependentRowsHaveUniqueCompliantForcesAndSeparatedState() throws {
        let input=try ResponseFixtures.input(duplicate:true), result=try ResponseFixtures.solve(input)
        let force=0.1/(0.001+0.01)
        for observation in result.observations { #expect(ResponseFixtures.close(observation.normalForce,force)) }
        #expect(result.effectiveMassInverse.allSatisfy { ResponseFixtures.close($0,0.5) })
        #expect(result.effectiveMassRank == nil && result.uniqueCompliantForce)
        let separated=try ResponseFixtures.solve(ResponseFixtures.input(separated:true))
        #expect(separated.observations[0].normalForce == 0 && separated.observations[0].active == .separated)
        #expect(separated.endpointVelocity == [0])
    }
    @Test func hingeLeverArmWorldWrenchAndPowerBalance() throws {
        let result=try ResponseFixtures.solve(ResponseFixtures.input(hinge:true))
        let force=0.1/(0.001+0.01/3)
        #expect(ResponseFixtures.close(result.effectiveMassInverse[0],1.0/3))
        #expect(ResponseFixtures.close(result.observations[0].normalForce,force))
        #expect(ResponseFixtures.close(result.generalizedContactForce[0],-force))
        #expect(ResponseFixtures.close(result.observations[0].wrenchOnB.torque.y,-force))
        #expect(ResponseFixtures.close(result.observations[0].wrenchOnA.torque.y,force))
        #expect(ResponseFixtures.close(result.actualPower,result.virtualPower))
        #expect(result.originalPhysicalResidual.wrenchResidual < 1e-9 && result.originalPhysicalResidual.powerResidual < 1e-9)
    }
    @Test func prescribedPointDriftRemainsInGapAndPower() throws {
        let result=try ResponseFixtures.solve(ResponseFixtures.input(drift:-0.5))
        let force=0.15/(0.001+0.005)
        #expect(ResponseFixtures.close(result.observations[0].normalForce,force))
        #expect(ResponseFixtures.close(result.observations[0].normalVelocity,0.1*force/2-0.5))
        #expect(ResponseFixtures.close(result.prescribedPower,-0.5*force))
        #expect(ResponseFixtures.close(result.actualPower,result.virtualPower+result.prescribedPower))
        #expect(result.originalPhysicalResidual.isAccepted)
    }
}
