import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct CurrentSamplingTests {
    @Test func virginSlipAndIssuedBristlesAreInstantaneousWithoutHistoryAdvance() throws {
        let pair=try CurrentContactFixtures.pair(friction:CurrentContactFixtures.friction())
        let virgin=try CurrentContactFixtures.history(pair)
        let sample=try CurrentContactFixtures.sample(CurrentContactFixtures.current(velocity:Vector3(80,-40,0)),pair:pair,accepted:virgin)
        #expect(sample.acceptedHistory == virgin)
        #expect(sample.tangentialForceFirst == 0 && sample.tangentialStoredEnergy == 0)
        #expect(sample.compressiveNormalForce == 10 && sample.normalStoredEnergy == 0.05)
        let issued=try CurrentContactFixtures.evaluate(CurrentContactFixtures.input(velocity:Vector3(1,0,0)),pair:pair,accepted:virgin).trialHistory
        let held=try CurrentContactFixtures.sample(CurrentContactFixtures.current(velocity:Vector3(3,0,-2),time:issued.timeSeconds),pair:pair,accepted:issued)
        #expect(held.acceptedHistory == issued)
        #expect(CurrentContactFixtures.close(held.tangentialForceFirst,-1))
        #expect(CurrentContactFixtures.close(held.tangentialStoredEnergy,0.0005))
        #expect(CurrentContactFixtures.close(held.relativeMechanicalPower,-23))
        #expect(CurrentContactFixtures.close(held.elasticPotentialRatePower,23))
        #expect(held.derivatives.tangentialForceBristleDerivative == -1000)
        #expect(held.originalRatePowerResidual <= 1e-10)
        let repeatSample=try CurrentContactFixtures.sample(CurrentContactFixtures.current(velocity:Vector3(-7,0,0),time:issued.timeSeconds),pair:pair,accepted:issued)
        #expect(repeatSample.tangentialForceFirst == held.tangentialForceFirst)
        #expect(repeatSample.acceptedHistory == issued && issued.sequence == 1 && issued.timeSeconds == 0.001)
        #expect(CurrentContactFixtures.close(issued.cumulativeTangentialDissipation,0.0005))
    }

    @Test func issuedSlidingStateDoesNotInferASpeedDependentCurrentReturnMap() throws {
        let pair=try CurrentContactFixtures.pair(friction:CurrentContactFixtures.friction())
        let trial=try CurrentContactFixtures.evaluate(CurrentContactFixtures.input(velocity:Vector3(20,0,0)),pair:pair)
        #expect(trial.frictionRegime == .sliding)
        let held=try CurrentContactFixtures.sample(CurrentContactFixtures.current(velocity:Vector3(0.1,0,0),time:0.001),pair:pair,accepted:trial.trialHistory)
        let mu=0.4+0.4*0.1/20.1
        #expect(CurrentContactFixtures.close(held.tangentialForceFirst,-10*mu))
        #expect(CurrentContactFixtures.close(held.staticFrictionConeUtilization,mu/0.8))
        #expect(held.acceptedHistory == trial.trialHistory)
    }

    @Test func normalCurvesClippingAndBranchPartialsMatchOriginalEquations() throws {
        let pair=try CurrentContactFixtures.pair(damping:4)
        let result=try CurrentContactFixtures.sample(CurrentContactFixtures.current(velocity:Vector3(0,0,-3)),pair:pair)
        #expect(result.compressiveNormalForce == 16 && result.elasticNormalForce == 10)
        #expect(result.normalDissipationPower == 18 && result.relativeMechanicalPower == -48)
        #expect(result.elasticPotentialRatePower == 30)
        #expect(result.derivatives.normalForcePenetrationDerivative == 1000 && result.derivatives.normalForceVelocityDerivative == -2)
        let clipped=try CurrentContactFixtures.sample(CurrentContactFixtures.current(velocity:Vector3(0,0,10)),pair:pair)
        #expect(clipped.compressiveNormalForce == 0 && clipped.elasticNormalForce == 10)
        #expect(clipped.normalDissipationPower == 100 && clipped.elasticPotentialRatePower == -100)
        #expect(clipped.derivatives.normalForcePenetrationDerivative == 0)
        let boundary=try CurrentContactFixtures.sample(CurrentContactFixtures.current(velocity:Vector3(0,0,5)),pair:pair)
        #expect(!boundary.derivatives.normalIsDifferentiable)
        let open=try CurrentContactFixtures.sample(CurrentContactFixtures.current(separation:0),pair:pair)
        #expect(!open.derivatives.normalIsDifferentiable)
        let k=(4.0/3)*(1e6/(2*(1-0.25*0.25)))*0.1.squareRoot(),delta=0.001
        for alpha in [0.0,0.5] {
            let selection:ContactNormalSelection=alpha == 0 ? .hertz(effectiveRadius:0.1,maximumPenetration:0.01,maximumNormalSpeed:10) : .huntCrossley(effectiveRadius:0.1,maximumPenetration:0.01,maximumNormalSpeed:10)
            let nonlinear=try CurrentContactFixtures.pair(selection:selection,alpha:alpha)
            let current=try CurrentContactFixtures.sample(CurrentContactFixtures.current(separation:-delta,velocity:Vector3(0,0,-2)),pair:nonlinear)
            let fe=k*delta*delta.squareRoot()
            #expect(CurrentContactFixtures.close(current.compressiveNormalForce,fe*(1+2*alpha)))
            #expect(CurrentContactFixtures.close(current.normalStoredEnergy,0.4*fe*delta))
            #expect(CurrentContactFixtures.close(current.derivatives.normalForcePenetrationDerivative,1.5*k*delta.squareRoot()*(1+2*alpha)))
            #expect(CurrentContactFixtures.close(current.derivatives.normalForceVelocityDerivative,-alpha*fe))
            let epsilon=1e-8
            let plus=try CurrentContactFixtures.sample(CurrentContactFixtures.current(separation:-(delta+epsilon),velocity:Vector3(0,0,-2)),pair:nonlinear)
            let minus=try CurrentContactFixtures.sample(CurrentContactFixtures.current(separation:-(delta-epsilon),velocity:Vector3(0,0,-2)),pair:nonlinear)
            #expect(abs((plus.compressiveNormalForce-minus.compressiveNormalForce)/(2*epsilon)-current.derivatives.normalForcePenetrationDerivative) <= 0.001)
        }
    }

    @Test func rollingSpinDerivativesAndPowerUseActualRegularizedCouples() throws {
        let pair=try CurrentContactFixtures.pair(rolling:0.1,spinning:0.2)
        let omega=try Vector3(3,4,2)
        let result=try CurrentContactFixtures.sample(CurrentContactFixtures.current(angular:omega),pair:pair)
        let rd=25.01.squareRoot(),sd=4.01.squareRoot()
        let expected=try Vector3(-1.5/rd,-2/rd,-2/sd)
        #expect(try CurrentContactFixtures.close(result.coupleOnB,expected))
        let expectedDissipation = try -expected.dot(omega)
        #expect(CurrentContactFixtures.close(result.resistanceDissipationPower,expectedDissipation))
        let derivative=result.derivatives
        #expect(CurrentContactFixtures.close(derivative.rollingFirstAngularDerivative,-0.5*(16.01)/(rd*rd*rd)))
        #expect(CurrentContactFixtures.close(derivative.rollingCrossAngularDerivative,6/(rd*rd*rd)))
        #expect(CurrentContactFixtures.close(derivative.spinningAngularDerivative,-0.01/(sd*sd*sd)))
        #expect(try CurrentContactFixtures.close(derivative.coupleCompressiveLoadDerivative,expected.scaled(by:0.1)))
        let direction=try Vector3(0.3,-0.2,0.7),epsilon=1e-5
        let plus=try CurrentContactFixtures.sample(CurrentContactFixtures.current(angular:omega.adding(direction.scaled(by:epsilon))),pair:pair)
        let minus=try CurrentContactFixtures.sample(CurrentContactFixtures.current(angular:omega.subtracting(direction.scaled(by:epsilon))),pair:pair)
        let fd=try plus.coupleOnB.subtracting(minus.coupleOnB).scaled(by:0.5/epsilon)
        let analytic=try Vector3(derivative.rollingFirstAngularDerivative*direction.x+derivative.rollingCrossAngularDerivative*direction.y,
            derivative.rollingCrossAngularDerivative*direction.x+derivative.rollingSecondAngularDerivative*direction.y,
            derivative.spinningAngularDerivative*direction.z)
        #expect(try CurrentContactFixtures.close(fd,analytic))
        #expect(result.originalRatePowerResidual <= 1e-10)
    }

    @Test func largeAngularSpeedRetainsSmallRegularizationDerivative() throws {
        let pair=try CurrentContactFixtures.pair(rolling:0.1,spinning:0.2)
        let result=try CurrentContactFixtures.sample(CurrentContactFixtures.current(angular:Vector3(1e8,0,1e8)),pair:pair)
        let expectedRolling = -0.5*0.01/1e24,expectedSpin = -0.01/1e24
        #expect(abs(result.derivatives.rollingFirstAngularDerivative/expectedRolling-1) < 1e-12)
        #expect(abs(result.derivatives.spinningAngularDerivative/expectedSpin-1) < 1e-12)
        #expect(result.derivatives.rollingFirstAngularDerivative < 0 && result.derivatives.spinningAngularDerivative < 0)
    }

    @Test func anisotropicIssuedStateAndCurrentPowerRotateCovariantly() throws {
        let pair=try CurrentContactFixtures.pair(friction:CurrentContactFixtures.friction(staticSecond:0.4,dynamicSecond:0.2),rolling:0.1,spinning:0.2)
        let issued=try CurrentContactFixtures.evaluate(CurrentContactFixtures.input(velocity:Vector3(1,2,0)),pair:pair).trialHistory
        let v=try Vector3(3,4,-1),w=try Vector3(1,2,3)
        let result=try CurrentContactFixtures.sample(CurrentContactFixtures.current(velocity:v,angular:w,time:0.001),pair:pair,accepted:issued)
        let rotation=try UnitQuaternion(axis:Vector3(1,2,3),angle:0.7)
        let rotated=try CurrentContactFixtures.sample(CurrentContactFixtures.current(velocity:rotation.rotating(v),angular:rotation.rotating(w),time:0.001,rotation:rotation),pair:pair,accepted:issued)
        #expect(try CurrentContactFixtures.close(rotated.forceOnB,rotation.rotating(result.forceOnB)))
        #expect(try CurrentContactFixtures.close(rotated.coupleOnB,rotation.rotating(result.coupleOnB)))
        #expect(CurrentContactFixtures.close(rotated.relativeMechanicalPower,result.relativeMechanicalPower))
        #expect(CurrentContactFixtures.close(rotated.elasticPotentialRatePower,result.elasticPotentialRatePower))
        #expect(CurrentContactFixtures.close(rotated.staticFrictionConeUtilization,(1.0/64+4.0/16).squareRoot()))
        #expect(rotated.acceptedHistory == issued)
        #expect(rotated.originalPowerResidual <= 1e-10 && rotated.originalRatePowerResidual <= 1e-10)
    }

    @Test func cohesionPotentialAndDerivativeAreSelectedBranchQuantities() throws {
        let pair=try CurrentContactFixtures.pair(cohesion:.reversibleLinear(tensileLimit:20,range:0.01))
        let result=try CurrentContactFixtures.sample(CurrentContactFixtures.current(separation:0.002,velocity:Vector3(0,0,3)),pair:pair)
        #expect(CurrentContactFixtures.close(result.cohesiveNormalForce,-16))
        #expect(CurrentContactFixtures.close(result.cohesivePotentialEnergy,-0.064))
        #expect(CurrentContactFixtures.close(result.completeCohesiveSeparationWork,0.1))
        #expect(CurrentContactFixtures.close(result.relativeMechanicalPower,-48))
        #expect(CurrentContactFixtures.close(result.elasticPotentialRatePower,48))
        #expect(result.normalDissipationPower == 0 && result.derivatives.cohesiveForceSeparationDerivative == 2000)
        let epsilon=1e-7
        let plus=try CurrentContactFixtures.sample(CurrentContactFixtures.current(separation:0.002+epsilon),pair:pair)
        let minus=try CurrentContactFixtures.sample(CurrentContactFixtures.current(separation:0.002-epsilon),pair:pair)
        #expect(abs((plus.cohesivePotentialEnergy-minus.cohesivePotentialEnergy)/(2*epsilon)+result.cohesiveNormalForce) < 1e-7)
        let boundary=try CurrentContactFixtures.sample(CurrentContactFixtures.current(separation:0),pair:pair)
        #expect(!boundary.derivatives.cohesionIsDifferentiable && boundary.derivatives.cohesiveForceSeparationDerivative == 2000)
        let end=try CurrentContactFixtures.sample(CurrentContactFixtures.current(separation:0.01),pair:pair)
        #expect(!end.derivatives.cohesionIsDifferentiable && end.cohesivePotentialEnergy == 0)
    }
}
