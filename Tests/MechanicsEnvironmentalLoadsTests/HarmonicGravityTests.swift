import SwiftMechanics
import Testing
@Suite(.timeLimit(.minutes(1))) struct HarmonicGravityTests {
    @Test func originalFieldExplicitRateAndAllDerivatives() throws {
        let service:any HarmonicGravityEvaluating=HarmonicGravityEvaluator()
        let law=try HarmonicGravityLaw(frame:EnvironmentalLoadFixture.frame(),constantAcceleration:Vector3(0,-10,0),
            cosineAcceleration:.unitX,sineAcceleration:.unitY,constantGradient:.zero,
            cosineGradient:Matrix3(2,0,0,0,0,0,0,0,0),sineGradient:Matrix3(0,0,0,0,3,0,0,0,0),
            angularFrequency:2,timeOrigin:0,phase:0)
        var work=try EnvironmentalLoadFixture.work()
        let point=try Vector3(2,3,0), velocity=try Vector3(1,2,0)
        func evaluate(_ p:Vector3,_ t:Double) throws -> HarmonicGravityResponse {
            try service.evaluate(law,body:EnvironmentalLoadFixture.body(),sample:GravitySample(point:p,mass:4),velocity:velocity,time:t,work:&work)
        }
        let r=try evaluate(point,0)
        #expect(r.load.forces.conservative == (try Vector3(20,-40,0)))
        #expect(r.load.potentialEnergy == 96 && r.explicitPotentialTimeDerivative == -132)
        #expect(r.mechanicalPower == -60 && r.potentialRate == -72)
        let t=0.4,h=1e-5, rt=try evaluate(point,t)
        let up=try evaluate(point,t+h).load.potentialEnergy!, um=try evaluate(point,t-h).load.potentialEnergy!
        #expect(EnvironmentalLoadFixture.close((up-um)/(2*h),rt.explicitPotentialTimeDerivative,tolerance:1e-8))
        for e in [Vector3.unitX,.unitY,.unitZ] {
            let rp=try evaluate(point.adding(e.scaled(by:h)),t), rm=try evaluate(point.subtracting(e.scaled(by:h)),t)
            #expect(try EnvironmentalLoadFixture.close(rp.load.forces.conservative.subtracting(rm.load.forces.conservative).scaled(by:1/(2*h)),rt.forcePositionDerivative.applying(to:e),tolerance:1e-8))
            let forceComponent=try rt.load.forces.conservative.dot(e)
            #expect(EnvironmentalLoadFixture.close(-(rp.load.potentialEnergy!-rm.load.potentialEnergy!)/(2*h),forceComponent,tolerance:1e-8))
        }
        let pathPlus=try evaluate(point.adding(velocity.scaled(by:h)),t+h), pathMinus=try evaluate(point.subtracting(velocity.scaled(by:h)),t-h)
        #expect(EnvironmentalLoadFixture.close((pathPlus.load.potentialEnergy!-pathMinus.load.potentialEnergy!)/(2*h),rt.potentialRate,tolerance:1e-8))
    }
    @Test func nonSymmetricGradientAndOverflowRefused() throws {
        #expect(throws:LoadError.invalidPassiveLaw) { try HarmonicGravityLaw(frame:EnvironmentalLoadFixture.frame(),constantAcceleration:.zero,cosineAcceleration:.zero,sineAcceleration:.zero,constantGradient:Matrix3(0,1,0,0,0,0,0,0,0),cosineGradient:.zero,sineGradient:.zero,angularFrequency:1,timeOrigin:0,phase:0) }
        let law=try HarmonicGravityLaw(frame:EnvironmentalLoadFixture.frame(),constantAcceleration:.zero,cosineAcceleration:.zero,sineAcceleration:.zero,constantGradient:.zero,cosineGradient:.zero,sineGradient:.zero,angularFrequency:Double.greatestFiniteMagnitude,timeOrigin:0,phase:0)
        var work=try EnvironmentalLoadFixture.work()
        #expect(throws:LoadError.nonFiniteResult) { try HarmonicGravityEvaluator().evaluate(law,body:EnvironmentalLoadFixture.body(),sample:GravitySample(point:.zero,mass:1),velocity:.zero,time:2,work:&work) }
    }
}
