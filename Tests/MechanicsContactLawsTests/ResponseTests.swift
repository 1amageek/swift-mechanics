import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ResponseTests {
    @Test func linearHertzAndHuntCrossleyMatchIndependentCurvesAndDerivatives() throws {
        let linear=try ContactFixtures.pair(damping:4)
        let compression=try ContactFixtures.evaluate(ContactFixtures.input(velocity:Vector3(0,0,-3)),pair:linear)
        #expect(ContactFixtures.close(compression.compressiveNormalForce,16))
        #expect(ContactFixtures.close(compression.normalStoredEnergy,0.05))
        #expect(ContactFixtures.close(compression.normalDissipationPower,18))
        #expect(compression.normalForcePenetrationDerivative == 1000 && compression.normalForceVelocityDerivative == -2)
        let unclipped=try ContactFixtures.evaluate(ContactFixtures.input(velocity:Vector3(0,0,10)),pair:linear)
        #expect(unclipped.compressiveNormalForce == 0 && unclipped.normalDissipationPower == 100)
        #expect(unclipped.normalForcePenetrationDerivative == 0 && unclipped.normalForceVelocityDerivative == 0)
        let hertz=try ContactFixtures.pair(selection:.hertz(effectiveRadius:0.1,maximumPenetration:0.01,maximumNormalSpeed:10))
        let hc=try ContactFixtures.pair(selection:.huntCrossley(effectiveRadius:0.1,maximumPenetration:0.01,maximumNormalSpeed:10),alpha:0.5)
        let k=(4.0/3)*(1e6/(2*(1-0.25*0.25)))*0.1.squareRoot()
        for delta in [0.0001,0.001,0.005] {
            let fe=k*delta*delta.squareRoot()
            let elastic=try ContactFixtures.evaluate(ContactFixtures.input(separation:-delta),pair:hertz)
            #expect(ContactFixtures.close(elastic.compressiveNormalForce,fe))
            #expect(ContactFixtures.close(elastic.normalStoredEnergy,0.4*fe*delta))
            let damped=try ContactFixtures.evaluate(ContactFixtures.input(separation:-delta,velocity:Vector3(0,0,-2)),pair:hc)
            #expect(ContactFixtures.close(damped.compressiveNormalForce,2*fe))
            #expect(ContactFixtures.close(damped.normalDissipationPower,2*fe))
            #expect(ContactFixtures.close(damped.normalForceVelocityDerivative,-0.5*fe))
            #expect(ContactFixtures.close(damped.normalForcePenetrationDerivative,3*k*delta.squareRoot()))
            let epsilon=1e-8
            let plus=try ContactFixtures.evaluate(ContactFixtures.input(separation:-(delta+epsilon),velocity:Vector3(0,0,-2)),pair:hc)
            let minus=try ContactFixtures.evaluate(ContactFixtures.input(separation:-(delta-epsilon),velocity:Vector3(0,0,-2)),pair:hc)
            #expect(abs((plus.compressiveNormalForce-minus.compressiveNormalForce)/(2*epsilon)-damped.normalForcePenetrationDerivative) <= 0.001)
        }
        let clipped=try ContactFixtures.evaluate(ContactFixtures.input(separation:-0.001,velocity:Vector3(0,0,3)),pair:hc)
        #expect(clipped.compressiveNormalForce == 0)
        #expect(ContactFixtures.close(clipped.normalDissipationPower,3*k*0.001*0.001.squareRoot()))
        #expect(throws:ContactLawError.normalDomain) { try ContactFixtures.evaluate(ContactFixtures.input(separation:-0.02),pair:hertz) }
        #expect(throws:ContactLawError.normalDomain) { try ContactFixtures.evaluate(ContactFixtures.input(velocity:Vector3(0,0,11)),pair:hertz) }
    }
    @Test func springStickRecoveryAndRegularizedSlipHaveActualDiscreteDissipation() throws {
        let pair=try ContactFixtures.pair(friction:ContactFixtures.friction())
        let accepted=try ContactFixtures.history(pair)
        let first=try ContactFixtures.evaluate(ContactFixtures.input(velocity:Vector3(1,0,0)),pair:pair,accepted:accepted)
        #expect(first.frictionRegime == .sticking)
        #expect(ContactFixtures.close(first.tangentialForceFirst,-1))
        #expect(ContactFixtures.close(first.tangentialStoredEnergy,0.0005))
        #expect(ContactFixtures.close(first.tangentialDissipationEnergy,0.0005))
        #expect(first.trialHistory.sequence == 1 && accepted.sequence == 0)
        let recovery=try ContactFixtures.evaluate(ContactFixtures.input(velocity:Vector3(-1,0,0),time:0.001),pair:pair,accepted:first.trialHistory)
        #expect(recovery.tangentialForceFirst == 0 && recovery.tangentialStoredEnergy == 0)
        #expect(ContactFixtures.close(recovery.tangentialDissipationEnergy,0.0005))
        let slip=try ContactFixtures.evaluate(ContactFixtures.input(velocity:Vector3(20,0,0)),pair:pair,accepted:accepted)
        let mu=0.4+0.4*0.1/(20+0.1)
        #expect(slip.frictionRegime == .sliding)
        #expect(ContactFixtures.close(slip.tangentialForceFirst,-10*mu))
        #expect(ContactFixtures.close(slip.frictionConeUtilization,1))
        let direct = -slip.tangentialForceFirst*0.02-slip.tangentialStoredEnergy
        #expect(ContactFixtures.close(slip.tangentialDissipationEnergy,direct))
        #expect(slip.tangentialDissipationEnergy > 0 && slip.originalTangentialEnergyResidual <= 1e-10)
        let repeatTrial=try ContactFixtures.evaluate(ContactFixtures.input(velocity:Vector3(20,0,0)),pair:pair,accepted:accepted)
        #expect(repeatTrial.trialHistory == slip.trialHistory)
        #expect(accepted.firstBristleDisplacement == 0 && accepted.cumulativeTangentialDissipation == 0)
    }
    @Test func anisotropicDiagonalSlipRotatesAndPreservesPower() throws {
        let pair=try ContactFixtures.pair(friction:ContactFixtures.friction(staticSecond:0.4,dynamicSecond:0.2),rolling:0.1,spinning:0.2)
        let v=try Vector3(3,4,-1),w=try Vector3(1,2,3)
        let response=try ContactFixtures.evaluate(ContactFixtures.input(velocity:v,angular:w,step:0.01),pair:pair)
        let mu1=0.4+0.4*0.1/5.1,mu2=0.2+0.2*0.1/5.1
        let norm=((30/(10*mu1))*(30/(10*mu1))+(40/(10*mu2))*(40/(10*mu2))).squareRoot()
        #expect(ContactFixtures.close(response.tangentialForceFirst,-30/norm))
        #expect(ContactFixtures.close(response.tangentialForceSecond,-40/norm))
        let rotation=try UnitQuaternion(axis:Vector3(1,2,3),angle:0.7)
        let rotated=try ContactFixtures.evaluate(ContactFixtures.input(velocity:rotation.rotating(v),angular:rotation.rotating(w),step:0.01,rotation:rotation),pair:pair)
        #expect(try ContactFixtures.close(rotated.forceOnB,rotation.rotating(response.forceOnB)))
        #expect(try ContactFixtures.close(rotated.coupleOnB,rotation.rotating(response.coupleOnB)))
        #expect(ContactFixtures.close(rotated.relativeMechanicalPower,response.relativeMechanicalPower))
        #expect(ContactFixtures.close(rotated.tangentialDissipationEnergy,response.tangentialDissipationEnergy))
        #expect(rotated.originalPowerResidual <= 1e-10)
    }
    @Test func rollingAndSpinningAreBoundedCouplesWithDissipation() throws {
        let pair=try ContactFixtures.pair(rolling:0.1,spinning:0.2)
        let result=try ContactFixtures.evaluate(ContactFixtures.input(angular:Vector3(3,4,2)),pair:pair)
        let expected=try Vector3(-0.5*3/(25.01.squareRoot()),-0.5*4/(25.01.squareRoot()),-2/(4.01.squareRoot()))
        #expect(try ContactFixtures.close(result.coupleOnB,expected))
        #expect(result.forceOnB == (try Vector3(0,0,10)))
        let power=try expected.dot(Vector3(3,4,2))
        #expect(ContactFixtures.close(result.resistanceDissipationPower,-power))
        #expect(result.resistanceDissipationPower > 0)
        #expect((result.coupleOnB.x*result.coupleOnB.x+result.coupleOnB.y*result.coupleOnB.y).squareRoot() <= 0.5)
        #expect(abs(result.coupleOnB.z) <= 1)
    }
    @Test func finiteRangeCohesionHasIndependentOpeningWorkAndNoLossDoubleCount() throws {
        let pair=try ContactFixtures.pair(damping:4,cohesion:.reversibleLinear(tensileLimit:20,range:0.01))
        var integral=0.0
        let intervals=100
        for i in 0...intervals {
            let s=0.01*Double(i)/Double(intervals)
            let result=try ContactFixtures.evaluate(ContactFixtures.input(separation:s,velocity:Vector3(0,0,1)),pair:pair)
            #expect(ContactFixtures.close(result.cohesiveNormalForce,-20*(1-s/0.01)))
            #expect(result.normalDissipationPower == 0 && result.resistanceDissipationPower == 0)
            integral += -result.cohesiveNormalForce*(i == 0 || i == intervals ? 0.5 : 1)*0.01/Double(intervals)
        }
        #expect(ContactFixtures.close(integral,0.1))
        let bonded=try ContactFixtures.evaluate(ContactFixtures.input(separation:0),pair:pair)
        let separated=try ContactFixtures.evaluate(ContactFixtures.input(separation:0.02),pair:pair)
        #expect(bonded.cohesivePotentialEnergy == -0.1 && separated.cohesivePotentialEnergy == 0)
        #expect(ContactFixtures.close(separated.completeCohesiveSeparationWork,separated.cohesivePotentialEnergy-bonded.cohesivePotentialEnergy))
        let compressed=try ContactFixtures.evaluate(ContactFixtures.input(velocity:Vector3(0,0,10)),pair:pair)
        #expect(compressed.cohesiveNormalForce == 0 && compressed.normalDissipationPower == 100)
        #expect(compressed.cohesivePotentialEnergy == -0.1)
    }
    @Test func normalLoadDecreaseAndContactAbsenceReleaseOwnedSpringEnergy() throws {
        let pair=try ContactFixtures.pair(friction:ContactFixtures.friction())
        let initial=try ContactFixtures.history(pair)
        let loaded=try ContactFixtures.evaluate(ContactFixtures.input(velocity:Vector3(5,0,0)),pair:pair,accepted:initial)
        #expect(loaded.frictionRegime == .sticking)
        let decreased=try ContactFixtures.evaluate(ContactFixtures.input(separation:-0.002,time:0.001),pair:pair,accepted:loaded.trialHistory)
        #expect(decreased.frictionRegime == .sliding)
        #expect(ContactFixtures.close(decreased.tangentialForceFirst,-1.6))
        #expect(ContactFixtures.close(decreased.tangentialDissipationEnergy,loaded.tangentialStoredEnergy-decreased.tangentialStoredEnergy))
        let absent=try ContactFixtures.evaluate(ContactFixtures.input(separation:0.1,time:0.001),pair:pair,accepted:loaded.trialHistory)
        #expect(absent.frictionRegime == .released && absent.tangentialStoredEnergy == 0)
        #expect(ContactFixtures.close(absent.tangentialDissipationEnergy,loaded.tangentialStoredEnergy))
        #expect(loaded.trialHistory.firstBristleDisplacement == 0.005)
    }
}
