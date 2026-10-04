import Foundation
import SwiftMechanics
import Testing

@Suite struct NonlinearPhysicalWitnessTests {
    @Test(.timeLimit(.minutes(1))) func actualMassReactionImpulseAndEnergyHaveIndependentOracles() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let equation=try NonlinearMechanismFixtures.equation(NonlinearMechanismFixtures.model(),drive:[0,-9.81],redundant:true)
            let (session,_)=try NonlinearMechanismFixtures.session(equation);defer { _=session.shutdown() }
            let capture=NonlinearTestCapture(),before=session.snapshot(),budget=try NumericalBudget(scalarStorage:1_000_000,arithmeticOperations:20_000_000,iterations:10000)
            _=try session.performTrial { (_:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                var work=NumericalWork(budget:budget)
                capture.store(try equation.consistent(time:0,point:[1.01,0,1,1],work:&work,control:control));return .reject
            }
            let result=try #require(capture.read()),q=result.point,v=Array(result.point[2...])
            #expect(abs(q[0]-1) < 1e-10);#expect(abs(q[1]) < 1e-10)
            #expect(abs(v[0]) < 1e-9);#expect(abs(v[1]-1) < 1e-9)
            #expect(abs(result.velocityProjection.generalizedReaction[0]+1) < 1e-9)
            #expect(abs(try #require(result.velocityProjection.kineticEnergyChange)+0.5) < 1e-9)
            #expect(abs(result.acceleration.values[0]+1) < 1e-9);#expect(abs(result.acceleration.values[1]+9.81) < 1e-9)
            #expect(abs(result.acceleration.generalizedReaction[0]+1) < 1e-9);#expect(abs(result.acceleration.generalizedReaction[1]) < 1e-9)
            #expect(abs(result.kineticEnergy-0.5) < 1e-9)
            #expect(result.acceleration.rank.rank == 1);#expect(result.acceleration.rank.reactionNullity == 1)
            #expect(session.snapshot() == before)
        }
    }
    @Test(.timeLimit(.minutes(1))) func movingQuadraticRowsRetainOriginalTimeDrift() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try NonlinearMechanismFixtures.model(q:[1,1],v:[0.1,0]),layout=try NonlinearMechanismFixtures.layout()
            let rows=[QuadraticConstraint(id:1,constant:-1,linear:[0,0],hessian:[8,0,0,0],timeLinear:-1,timeQuadratic:-0.5,mixedTime:[0,0]),
                      QuadraticConstraint(id:2,constant:-1,linear:[0,0],hessian:[0,0,0,18],timeLinear:0,timeQuadratic:0,mixedTime:[0,0])]
            let system=try QuadraticConstraintSystem(layout:layout,rows:rows,minimumPosition:[0.5,0.5],maximumPosition:[10,10],minimumTime:0,maximumTime:20)
            let equation=try NonlinearMechanismEquation(identity:"moving-loop",model:model,constraints:system,velocityLayout:layout,drive:[2,3],
                policy:NonlinearMechanismFixtures.policy(),projection:NonlinearMechanismFixtures.projection(layout),admission:NonlinearMechanismFixtures.admission(),maximumIdentityBytes:8192)
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:0.05);defer { _=session.shutdown() }
            let result=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:5)
            let s=result.accepted.checkpoint.physical
            #expect(abs(s.q[0]-1.5) < 1e-9);#expect(abs(s.q[1]-1) < 1e-9)
            #expect(abs(s.v[0]-0.1) < 1e-9);#expect(abs(s.v[1]) < 1e-9)
            #expect(s.acceleration.allSatisfy({abs($0) < 1e-8}))
        }
    }
    @Test(.timeLimit(.minutes(1))) func quaternionCurvedConstraintRequiresNonzeroNdotBias() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let c=cos(0.4),s=sin(0.4)
            let model=try NonlinearMechanismFixtures.model(q:[c,0,s,0],v:[-tan(0.4),0,1],spherical:true)
            let base=try NonlinearMechanismFixtures.quaternionEquation(model),q=base.constraints.layout
            let rows=[QuadraticConstraint(id:1,constant:-c,linear:[1,0,0,0],hessian:[Double](repeating:0,count:16),timeLinear:0,timeQuadratic:0,mixedTime:[0,0,0,0]),
                      QuadraticConstraint(id:2,constant:0,linear:[0,1,0,0],hessian:[Double](repeating:0,count:16),timeLinear:0,timeQuadratic:0,mixedTime:[0,0,0,0])]
            let system=try QuadraticConstraintSystem(layout:q,rows:rows,minimumPosition:[-2,-2,-2,-2],maximumPosition:[2,2,2,2],minimumTime:0,maximumTime:20)
            let equation=try NonlinearMechanismEquation(identity:"curved-quaternion-loop",model:model,constraints:system,velocityLayout:base.velocityLayout,drive:[0,0,0],
                policy:base.policy,projection:base.projection,admission:NonlinearMechanismFixtures.admission(),maximumIdentityBytes:8192)
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:0.01);defer { _=session.shutdown() }
            let result=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:1)
            let state=result.accepted.checkpoint.physical,w=state.v,a=state.acceleration
            #expect(abs(state.q[0]-c) < 1e-9);#expect(abs(state.q[1]) < 1e-9)
            let norm=w.reduce(0){$0+$1*$1},dot=state.q[1]*a[0]+state.q[2]*a[1]+state.q[3]*a[2]
            #expect(abs(-0.5*dot-0.25*norm*state.q[0]) < 1e-7)
            #expect(a.reduce(0){$0+$1*$1} > 0.01)
            #expect(abs(norm-1/(c*c)) < 1e-5)
        }
    }
}
