import CMechanicsMath
import MechanicsCore
import MechanicsConstraints
import Testing

@Suite(.timeLimit(.minutes(1)))
struct EquationTests {
    @Test func explicitTimeMixedPolynomialHasIndependentAcceleration() throws {
        let layout=try ConstraintFixtures.layout(scales:[2,0.5],timeScale:3)
        let row=QuadraticConstraint(id:9,constant:0,linear:[0,2],hessian:[2,0,0,0],timeLinear:0,timeQuadratic:-2,mixedTime:[1,0])
        let system=try ConstraintFixtures.system([row],layout:layout)
        var work=try ConstraintFixtures.work()
        let evaluator: any ConstraintEvaluating=QuadraticConstraintEvaluator()
        let q=[1.0,0.1], v=[0.8,0.1], a=[0.2,-0.03], time=1.5
        let result=try evaluator.evaluate(system,position:q,velocity:v,time:time,policy:ConstraintFixtures.evaluation(),work:&work)
        #expect(ConstraintFixtures.close(result.values[0],0.65))
        #expect(result.jacobian == [1.5,2])
        #expect(ConstraintFixtures.close(result.timeDerivative[0],-0.5))
        #expect(ConstraintFixtures.close(result.accelerationBias[0],3.28))
        func original(_ dt: Double) -> Double {
            let x=(q[0]+v[0]*dt+0.5*a[0]*dt*dt)/2
            let y=(q[1]+v[1]*dt+0.5*a[1]*dt*dt)/0.5, tau=(time+dt)/3
            return x*x+2*y+tau*x-tau*tau
        }
        let d=1e-4, expected=(original(d)-2*original(0)+original(-d))/(d*d)
        let actual=(1.5*a[0]*9/2+2*a[1]*9/0.5+result.accelerationBias[0])/9
        #expect(ConstraintFixtures.close(expected,actual,1e-6))
    }
    @Test func smoothPrescribedQuadraticTrajectoryCarriesAllTimeTerms() throws {
        let row=QuadraticConstraint(id:2,constant:0,linear:[1],hessian:[0],timeLinear:0,timeQuadratic:-2,mixedTime:[0])
        let system=try ConstraintFixtures.system([row],layout:ConstraintFixtures.layout(1))
        var work=try ConstraintFixtures.work()
        let result=try QuadraticConstraintEvaluator().evaluate(system,position:[4],velocity:[4],time:2,policy:ConstraintFixtures.evaluation(),work:&work)
        #expect(result.values == [0]); #expect(result.timeDerivative == [-4]); #expect(result.accelerationBias == [-2])
        #expect(result.jacobian[0]*4+result.timeDerivative[0] == 0)
        #expect(result.jacobian[0]*2+result.accelerationBias[0] == 0)
    }
    @Test func knifeEdgeNonintegrableVelocityAndAccelerationAreActual() throws {
        let layout=try ConstraintCoordinateLayout(coordinateIDs:[1,2,3],dimensions:[.length,.length,.angle],scales:[2,2,1],timeScale:3,revision:7)
        let theta=0.4, speed=2.0, omega=0.7
        let v=[speed*sm_cos(theta),speed*sm_sin(theta),omega]
        var work=try ConstraintFixtures.work()
        let evaluator: any KnifeEdgeEvaluating=PlanarKnifeEdgeEvaluator()
        let sample=try evaluator.evaluate(layout:layout,rowID:9,position:[0,0,theta],velocity:v,policy:ConstraintFixtures.evaluation(),work:&work)
        #expect(!sample.isIntegrable)
        #expect(ConstraintFixtures.close(sample.rows[0]*v[0]*3/2+sample.rows[1]*v[1]*3/2,0))
        let ax = -speed*omega*sm_sin(theta), ay=speed*omega*sm_cos(theta)
        #expect(ConstraintFixtures.close(sample.rows[0]*ax*9/2+sample.rows[1]*ay*9/2+sample.accelerationBias[0],0))
        #expect(ConstraintFixtures.close(sample.accelerationBias[0],-6.3))
    }
}
