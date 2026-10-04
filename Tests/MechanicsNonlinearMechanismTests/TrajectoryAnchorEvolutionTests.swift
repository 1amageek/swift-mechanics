import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(2))) struct TrajectoryAnchorEvolutionTests {
    @Test func actualAnchorHarmonicAndC2SamplingRetainsOriginalPrescribedPowerAndBoundary() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            for piecewise in [true,false] {
                let fixture=try TrajectoryAnchorEvolutionFixture(piecewise:piecewise),query=TrajectoryFaultBoundaryQuery(),equation=try fixture.equation(query:query)
                let (session,continuation)=try PlanarEvolutionFixtures.session(equation,step:0.02);defer { _=session.shutdown() }
                let t=1.2,final=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:t).accepted,state=final.checkpoint.physical
                let jet=TrajectoryAnchorOracle(t,piecewise:piecewise),relativeQ=0.3+0.5*t+0.2*t*t-jet.angle,relativeV=0.5+0.4*t-jet.rate
                #expect(abs(state.q[fixture.first]-relativeQ) < 2e-8 && abs(state.q[fixture.second]-relativeQ) < 2e-8)
                #expect(abs(state.v[0]-relativeV) < 2e-8 && abs(state.acceleration[0]-(0.4-jet.second)) < 1e-8)
                let capture=NonlinearTestCapture()
                _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                    var work=NumericalWork(budget:equation.publicationBudget)
                    capture.store(try equation.consistent(time:t,point:state.q+state.v,work:&work,control:control));return .reject
                }
                let result=try #require(capture.read()),energy=try #require(result.mechanicalEnergy)
                let velocitySquared=jet.velocity.reduce(0.0) { $0+$1*$1 },translation=zip(jet.velocity,jet.acceleration).reduce(0.0) { $0+$1.0*$1.1 }
                let kinetic=1.5*velocitySquared+0.5*jet.rate*jet.rate+(jet.rate+relativeV)*(jet.rate+relativeV)
                let anchorPower=3*translation+(jet.second+0.8)*jet.rate
                #expect(abs(energy.kineticEnergy-kinetic) < 2e-8)
                #expect(abs(energy.requiredPrescribedPower-anchorPower) < 2e-8)
                #expect(abs(energy.kineticEnergyRate-(anchorPower+0.8*relativeV)) < 2e-8)
                var work=try GeometricEvolutionFixtures.work()
                let expected=try AnalyticPrescribedTrajectorySampler().sample(fixture.program,time:t,policy:fixture.program.policy,work:&work)
                #expect(state.prescribedAnchors == expected.anchors)
                if piecewise { #expect(query.observedAtKnot()) }
                let codec=NativeRuntimeCheckpointCodec(),saved=try session.checkpoint(codec:codec)
                let freshFixture=try TrajectoryAnchorEvolutionFixture(piecewise:piecewise),freshEquation=try freshFixture.equation(),(fresh,freshContinuation)=try PlanarEvolutionFixtures.session(freshEquation,step:0.02);defer { _=fresh.shutdown() }
                _=try fresh.restart(saved,codec:codec)
                let a=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:1.3).accepted
                let b=try ProjectedNonlinearMechanismEvolution().advance(fresh,equations:freshEquation,continuation:freshContinuation,to:1.3).accepted
                #expect(a == b)
            }
        }
    }
    @Test func resetAnchorSamplerPreservesWholeAcceptedPrefix() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try TrajectoryAnchorEvolutionFixture(piecewise:false),equation=try fixture.equation(sampler:TrajectoryFaultSampler())
            let (session,continuation)=try PlanarEvolutionFixtures.session(equation,step:0.02);defer { _=session.shutdown() }
            let prefix=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.04).accepted
            let codec=NativeRuntimeCheckpointCodec(),before=try session.checkpoint(codec:codec)
            do throws(NonlinearMechanismFailure) { _=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.08);Issue.record("Reset anchor supplier published") }
            catch { #expect(error.cause.code == .invalidOwnerAccess && error.work.failedSupplierWorkUnavailable && error.lastAccepted == prefix) }
            #expect(try session.checkpoint(codec:codec) == before)
        }
    }
}
