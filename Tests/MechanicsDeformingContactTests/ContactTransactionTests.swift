import Testing
import MechanicsCore
import MechanicsNumerics
import MechanicsContactLaws
import MechanicsDeformingContact
@Suite struct ContactTransactionTests {
    @Test func rejectionIndependentStatesAndDeformedHistoryContinuation() throws {
        let snapshot=try DeformingFixtures.selfMoving(), pair=try DeformingFixtures.pair(), witness=try DeformingFixtures.selfWitness(snapshot)
        let binding=SurfaceContactBinding(key:"self",witness:witness,pair:pair,currentObstacle:nil)
        var work=try DeformingFixtures.work(), law=try DeformingFixtures.lawWork(); let service:any SurfaceContactTransacting=ValueSurfaceContactTransactions()
        let state=try service.initialState(snapshot,bindings:[binding],policy:DeformingFixtures.policy(),work:&work,lawWork:&law)
        let independent=try service.initialState(snapshot,bindings:[binding],policy:DeformingFixtures.policy(),work:&work,lawWork:&law)
        let step=try service.trial(state,snapshot:snapshot,bindings:[binding],timeStep:0.001,policy:DeformingFixtures.policy(),lawPolicy:DeformingFixtures.lawPolicy(),work:&work,lawWork:&law)
        #expect(try service.reject(step,from:state) === state); #expect(state.histories[0].sequence == 0); #expect(independent.histories[0].sequence == 0)
        do { _=try service.accept(step,from:independent); Issue.record("A trial accepted against another state owner.") }
        catch DeformingContactError.staleHistory {} catch { throw error }
        let accepted=try service.accept(step,from:state)
        #expect(accepted.acceptedTime == 0.001); #expect(accepted.histories[0].sequence == 1); #expect(state.acceptedTime == 0)
        var positions=snapshot.state.positions
        for i in 4..<8 { positions[i]=try positions[i].adding(Vector3(0.001,0,0)) }
        let next=try DeformingFixtures.snapshot(snapshot.surface,positions:positions,velocities:snapshot.state.velocities,revision:2,time:0.001,previous:snapshot)
        let nextBinding=SurfaceContactBinding(key:"self",witness:try DeformingFixtures.selfWitness(next),pair:pair,currentObstacle:nil)
        let nextStep=try service.trial(accepted,snapshot:next,bindings:[nextBinding],timeStep:0.001,policy:DeformingFixtures.policy(),lawPolicy:DeformingFixtures.lawPolicy(),work:&work,lawWork:&law)
        #expect(nextStep.contacts[0].response.trialHistory.sequence == 2)
        #expect(nextStep.contacts[0].response.trialHistory.identity == accepted.histories[0].identity)
        #expect(accepted.histories[0].sequence == 1)
    }
    @Test func cancellationAndMissingRegistrationPreservePrefix() throws {
        let s=try DeformingFixtures.selfMoving(), pair=try DeformingFixtures.pair(), binding=SurfaceContactBinding(key:"self",witness:try DeformingFixtures.selfWitness(s),pair:pair,currentObstacle:nil)
        var work=try DeformingFixtures.work(), law=try DeformingFixtures.lawWork(); let service:any SurfaceContactTransacting=ValueSurfaceContactTransactions()
        let state=try service.initialState(s,bindings:[binding],policy:DeformingFixtures.policy(),work:&work,lawWork:&law)
        do { _=try service.trial(state,snapshot:s,bindings:[binding],timeStep:0.001,policy:DeformingFixtures.policy(cancelled:true),lawPolicy:DeformingFixtures.lawPolicy(),work:&work,lawWork:&law); Issue.record("Cancelled contact trial succeeded.") }
        catch DeformingContactError.cancelled {} catch { throw error }
        do { _=try service.trial(state,snapshot:s,bindings:[],timeStep:0.001,policy:DeformingFixtures.policy(),lawPolicy:DeformingFixtures.lawPolicy(),work:&work,lawWork:&law); Issue.record("Missing registration succeeded.") }
        catch DeformingContactError.capacityExceeded {} catch { throw error }
        #expect(state.generation == 0); #expect(state.histories[0].sequence == 0)
    }
}
