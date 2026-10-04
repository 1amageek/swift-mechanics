import SwiftMechanics
import Testing

@Suite struct ObservationSourceTests {
    @Test func solvedAccelerationReplacesOnlyAdmittedAccelerationAndRejectsMovedSource() throws {
        let model=try ObservationFixtures.model(kind:.prismatic),solved=try ObservationFixtures.supported(model)
        let declared=try KinematicState(revision:1,time:2,q:[0],v:[0],acceleration:[99]),state=try model.makeState(declared),policy=try ObservationFixtures.policy()
        var work=try ObservationFixtures.work()
        let prepared=try ReferenceObservationSourcePreparer().prepare(model:model,state:state,solved:solved,policy:policy,work:&work)
        #expect(abs(prepared.state.state.acceleration[0]) < 1e-10);#expect(state.state.acceleration == [99])
        #expect(prepared.accelerationAuthority == .constraintSolved)
        let moved=try model.makeState(KinematicState(revision:1,time:2,q:[1],v:[0],acceleration:[0]))
        do throws(ObservationError) { _=try ReferenceObservationSourcePreparer().prepare(model:model,state:moved,solved:solved,policy:policy,work:&work);Issue.record("Foreign source pose accepted.") }
        catch { if case .staleSource=error {} else { Issue.record("Wrong source binding failure.") } }
        let jump=try ObservationFixtures.supported(model,impulse:true)
        do throws(ObservationError) { _=try ReferenceObservationSourcePreparer().prepare(model:model,state:state,solved:jump,policy:policy,work:&work);Issue.record("Impulse used as acceleration.") }
        catch { if case .missingAcceleration=error {} else { Issue.record("Wrong acceleration authority failure.") } }
    }
    @Test func foreignModelAndUnknownFrameSupplierFailWithoutObservation() throws {
        let model=try ObservationFixtures.model(),other=try ObservationFixtures.model(identity:"other-model"),foreign=try other.makeState(other.descriptor.initialState)
        let policy=try ObservationFixtures.policy();var work=try ObservationFixtures.work()
        do throws(ObservationError) { _=try ReferenceObservationSourcePreparer().prepare(model:model,state:foreign,policy:policy,work:&work);Issue.record("Foreign model accepted.") }
        catch { #expect(error.failedSupplierWorkUnavailable);if case .compilation=error {} else { Issue.record("Wrong model failure.") } }
        let source=try ObservationFixtures.source(model),mount=try ObservationFixtures.mount()
        do throws(ObservationError) { _=try ReferenceKinematicObserver(composer:FailingFrameComposer()).motion(source:source,mount:mount,policy:policy,work:&work);Issue.record("Failed supplier produced observation.") }
        catch { #expect(error.failedSupplierWorkUnavailable);if case .frameSupplierFailure=error {} else { Issue.record("Wrong supplier failure.") } }
        let rotating=try ObservationFixtures.source(ObservationFixtures.model(q:[Double.pi/2],v:[2],a:[3]))
        let offset=try ObservationFixtures.mount(offset:Vector3(2,0,0)),before=work.operations
        do throws(ObservationError) {
            _=try ReferenceKinematicObserver(composer:FailingFrameComposer(returnsStationary:true))
                .motion(source:rotating,mount:offset,policy:policy,work:&work)
            Issue.record("Unrelated successful composer motion was published.")
        } catch {
            if case .invalidSupplierEvidence=error {} else { Issue.record("Wrong successful supplier failure.") }
            #expect(!error.failedSupplierWorkUnavailable)
        }
        #expect(work.operations > before)
        #expect(rotating.state.state.v == [2] && rotating.state.state.acceleration == [3])
    }
    @Test func identityKindsAndUnsupportedMountingReject() throws {
        let body=try ObservationFixtures.id(.body,"body"),frame=try ObservationFixtures.id(.frame,"sensor-frame")
        do throws(ObservationError) { _=try ObservationMount(sensor:body,body:body,sensorFrame:frame,sensorToBody:.identity);Issue.record("Non-sensor identity accepted.") }
        catch { if case .invalidMounting=error {} else { Issue.record("Wrong mounting identity failure.") } }
        let source=try ObservationFixtures.source(ObservationFixtures.model()),sensor=try ObservationFixtures.id(.sensor,"sensor")
        let wrong=try ObservationMount(sensor:sensor,body:body,sensorFrame:source.snapshot.tree.worldFrame,sensorToBody:.identity),policy=try ObservationFixtures.policy()
        var work=try ObservationFixtures.work()
        do throws(ObservationError) { _=try ReferenceKinematicObserver().motion(source:source,mount:wrong,policy:policy,work:&work);Issue.record("World frame reused for sensor.") }
        catch { if case .invalidMounting=error {} else { Issue.record("Wrong frame collision failure.") } }
    }
}

extension ObservationSourceTests {
    @Test func currentStorageFailurePreservesSourceWithoutPublication() throws {
        let model=try ObservationFixtures.model(),state=try model.makeState(model.descriptor.initialState),policy=try ObservationFixtures.policy()
        var work=NumericalWork(budget:try NumericalBudget(scalarStorage:0,arithmeticOperations:10000,iterations:0))
        do throws(ObservationError) { _=try ReferenceObservationSourcePreparer().prepare(model:model,state:state,policy:policy,work:&work);Issue.record("Storage bound ignored.") }
        catch { if case .numerical=error {} else { Issue.record("Wrong storage failure.") };#expect(!error.failedSupplierWorkUnavailable) }
        #expect(state.state == model.descriptor.initialState);#expect(work.peakScalarStorage == 0)
        let source=try ObservationFixtures.source(model),mount=try ObservationFixtures.mount()
        var verification=NumericalWork(budget:try NumericalBudget(scalarStorage:95,arithmeticOperations:10000,iterations:0))
        do throws(ObservationError) {
            _=try ReferenceKinematicObserver().motion(source:source,mount:mount,policy:policy,work:&verification)
            Issue.record("Original verification exceeded the caller storage budget.")
        } catch {
            if case .numerical(.resourceLimit(resource:.scalarStorage,limit:95))=error {} else { Issue.record("Wrong verification storage failure.") }
            #expect(!error.failedSupplierWorkUnavailable)
        }
        #expect(verification.operations > 0 && verification.peakScalarStorage < 96)
        #expect(source.state.state == state.state)
    }
}
