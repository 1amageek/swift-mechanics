import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct GranularRuntimePhysicalTests {
    @Test func actualRuntimeGravityChoiceShearImpulseTorqueAndWork() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime availability missing");return }
        let f=try GranularRuntimeFixture();defer { _=f.session.shutdown() }
        var expected=RuntimeRandomState(seed:123);let choice=try expected.next()%2
        let gravity=choice == 0 ? -9.0 : -10.0,model=f.model,operation=f.operation,physics=f.source.physicsBudget
        _=try f.session.performTrial { (trial: inout RuntimeTrial,control: inout RuntimeStepControl) throws(RuntimeFailure) in
            var work: GranularRuntimeWork
            do { work=try GranularRuntimeFixture.work(physics) } catch { throw RuntimeFailure(.invalidInput,message:"Fixture budgets failed") }
            let result=try operation.advance(model:model,duration:0.001,trial:&trial,control:&control,work:&work)
            // kPair=1000, penetration=.01; ktPair=100, trial bristle=.001.
            let vx=0.0001,vz=(10+gravity)*0.001,wy = -0.000495
            #expect(abs(result.contacts[0].response.compressiveNormalForce-10) < 1e-10)
            #expect(abs(result.state.motions[0].velocity.x-vx) < 1e-10)
            #expect(abs(result.state.motions[0].velocity.z-vz) < 1e-10)
            #expect(abs(result.state.motions[0].angularVelocity.y-wy) < 1e-10)
            #expect(abs(result.state.motions[0].position.z-(0.49+0.001*vz)) < 1e-10)
            #expect(abs(result.boundaryReactions[0].force.x+0.1) < 1e-10)
            #expect(abs(result.evidence.prescribedBoundaryWork+0.0001) < 1e-10)
            let kinetic=0.5*(vx*vx+vz*vz)+0.5*0.1*wy*wy
            #expect(abs(result.evidence.kineticEnergyChange-kinetic) < 1e-10)
            #expect(abs(result.evidence.particleMidpointWork-kinetic) < 1e-10)
            #expect(abs(result.evidence.originalWorkResidual) < 1e-10)
            #expect(result.state.contacts[0].basis != nil && result.state.contacts[0].history.sequence == 1)
            #expect(abs(result.state.contacts[0].history.firstBristleDisplacement-0.001) < 1e-10)
            #expect(work.suppliers.calls >= 4 && work.numerical.operations > 0)
            return .accept
        }
        let state=try f.accepted(),checkpoint=f.session.snapshot().checkpoint
        #expect(state.gravityChoiceIndices == [choice] && state.random == expected && checkpoint.random == expected)
        #expect(state.particles.random.draws == 0 && state.particles.steps == 1 && checkpoint.acceptedSteps == 1)
    }
    @Test func computedRejectedTrialPublishesNeitherHistoryNorRng() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime availability missing");return }
        let f=try GranularRuntimeFixture();defer { _=f.session.shutdown() }
        let prefix=f.session.snapshot(),wire=try f.session.checkpoint(codec:NativeRuntimeCheckpointCodec())
        let rejected=try f.advance(decision:.reject)
        #expect(rejected.decision == .reject && rejected.accepted == prefix && f.session.snapshot() == prefix)
        #expect(try f.session.checkpoint(codec:NativeRuntimeCheckpointCodec()) == wire)
        #expect(try f.accepted().particles.contacts[0].history.sequence == 0)
        _=try f.advance()
        #expect(try f.accepted().random.draws == 1 && f.session.snapshot().checkpoint.acceptedSteps == 1)
    }
    @Test func freshSourceModelContributorAndRuntimeReplayExactHistoryAndChoices() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime availability missing");return }
        let f=try GranularRuntimeFixture();defer { _=f.session.shutdown() }
        for _ in 0..<3 { _=try f.advance() }
        let prefix=f.session.snapshot(),wire=try f.session.checkpoint(codec:NativeRuntimeCheckpointCodec())
        let uninterrupted=try f.advance(),expected=try f.accepted()
        let fresh=try GranularRuntimeFixture();defer { _=fresh.session.shutdown() }
        #expect(fresh.model.stamp == f.model.stamp)
        #expect(fresh.source !== f.source && fresh.source.initial.model !== f.source.initial.model)
        #expect(fresh.journal !== f.journal && fresh.session !== f.session)
        _=try fresh.session.restart(wire,codec:NativeRuntimeCheckpointCodec())
        #expect(fresh.session.snapshot() == prefix)
        #expect(try fresh.session.checkpoint(codec:NativeRuntimeCheckpointCodec()) == wire)
        let resumed=try fresh.advance(),actual=try fresh.accepted()
        #expect(resumed.accepted == uninterrupted.accepted && actual.random == expected.random)
        #expect(actual.particles.motions == expected.particles.motions && actual.gravityChoiceIndices == expected.gravityChoiceIndices)
        #expect(actual.particles.timeSeconds.bitPattern == expected.particles.timeSeconds.bitPattern && actual.particles.steps == 4)
        for i in actual.particles.contacts.indices {
            #expect(actual.particles.contacts[i].history == expected.particles.contacts[i].history)
            #expect(actual.particles.contacts[i].basis == expected.particles.contacts[i].basis)
        }
        #expect(actual.particles.contacts[0].history.firstBristleDisplacement > 0.001)
    }
}
