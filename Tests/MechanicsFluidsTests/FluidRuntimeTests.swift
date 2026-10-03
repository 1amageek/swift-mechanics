import Testing
import MechanicsModel
import MechanicsCompiler
import MechanicsNumerics
import MechanicsRuntime
import MechanicsFluids
struct FluidRuntimeTests {
    @Test func actualAcceptedEvolutionRejectedRollbackAndCheckpointReplay() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try FluidRuntimeFixture(),boundary=try FluidFixtures.boundary(gradient:-2)
            let initial=try fixture.accepted()
            let rejected=try fixture.advance(boundary:boundary,duration:0.05,decision:.reject)
            #expect(rejected.decision == .reject); #expect(try fixture.accepted() == initial)
            for _ in 0..<4 { _=try fixture.advance(boundary:boundary,duration:0.05,decision:.accept) }
            let accepted=try fixture.accepted(); #expect(accepted.sequence == 4);#expect(accepted.time == 0.2)
            #expect(accepted.velocities[3] > 0)
            let snapshot=fixture.session.snapshot()
            #expect(snapshot.physical.state.time == accepted.time)
            #expect(snapshot.physical.state.q.isEmpty); #expect(snapshot.physical.state.v.isEmpty)
            let checkpoint=try fixture.session.checkpoint(codec:NativeRuntimeCheckpointCodec())
            let uninterrupted=try fixture.advance(boundary:boundary,duration:0.05,decision:.accept)
            let after=try fixture.accepted()
            _=try fixture.session.restart(checkpoint,codec:NativeRuntimeCheckpointCodec())
            #expect(try fixture.accepted() == accepted)
            let replay=try fixture.advance(boundary:boundary,duration:0.05,decision:.accept)
            #expect(try fixture.accepted() == after)
            #expect(replay.accepted.physical.state == uninterrupted.accepted.physical.state)
            _=fixture.session.shutdown()
        } else { Issue.record("Runtime fluid verification requires the declared Runtime availability.") }
    }
    @Test func failuresPreservePrefixAndPayloadTimeCannotPretendAssociated() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try FluidRuntimeFixture(),boundary=try FluidFixtures.boundary(gradient:-2)
            _=try fixture.advance(boundary:boundary,duration:0.05,decision:.accept)
            let prefix=try fixture.accepted()
            do throws(RuntimeFailure) { _=try fixture.advance(boundary:boundary,duration:0,decision:.accept); Issue.record("Expected fluid duration rejection") }
            catch { #expect(error.code == .invalidContributor) }
            #expect(try fixture.accepted() == prefix)
            let mismatch=try FluidRuntimeFixture(payloadTime:1)
            do throws(RuntimeFailure) { _=try mismatch.advance(boundary:boundary,duration:0.1,decision:.accept); Issue.record("Expected history time association rejection") }
            catch { #expect(error.code == .invalidState) }
            #expect(try mismatch.accepted().time == 1)
            let budget=try FluidRuntimeFixture(maximumStepWork:2),budgetInitial=try budget.accepted()
            do throws(RuntimeFailure) { _=try budget.advance(boundary:boundary,duration:0.1,decision:.accept); Issue.record("Expected runtime work rejection") }
            catch { #expect(error.code == .capacityExceeded) }
            #expect(try budget.accepted() == budgetInitial)
            _=fixture.session.shutdown();_=mismatch.session.shutdown();_=budget.session.shutdown()
        } else { Issue.record("Runtime fluid verification requires the declared Runtime availability.") }
    }
    @Test func failedActualFluidSolverPreservesUnknownWorkAcrossRuntimeBoundary() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime availability missing."); return }
        let fixture = try FluidRuntimeFixture(), prefix = fixture.session.snapshot()
        let boundary = try FluidFixtures.boundary(gradient: -2), policy = try FluidFixtures.policy()
        let operation = fixture.operation, model = fixture.model
        do throws(RuntimeFailure) {
            _ = try fixture.session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                var work: NumericalWork, bytes: FluidByteWork
                do {
                    work = NumericalWork(budget: try NumericalBudget(scalarStorage: 100000, arithmeticOperations: 100000, iterations: 0))
                    bytes = try FluidByteWork(maximumBytes: 10000, maximumVisitedBytes: 100000)
                } catch { throw RuntimeFailure(.invalidInput, message: "Fixture budget construction failed.") }
                do throws(RuntimeFailure) {
                    _ = try operation.advance(model: model, boundary: boundary, duration: 0.1, policy: policy,
                        trial: &trial, control: &control, numerical: &work, bytes: &bytes)
                } catch { #expect(work.operations > 0); throw error }
                return .accept
            }
            Issue.record("Exhausted solver unexpectedly published fluid state.")
        } catch { #expect(error.failedSupplierWorkUnavailable && error.lastAccepted == prefix) }
        #expect(fixture.session.snapshot() == prefix && fixture.session.profile().attemptedTransactions == 1)
        _ = fixture.session.shutdown()
    }
    @Test func directRequiredContributorValidationRejectsMissingBindingAndBudget() throws {
        let model=try FluidFixtures.model(),c=try FluidFixtures.channel(model:model.stamp),b=try FluidFixtures.boundary()
        let codec=try FixedFluidContinuationCodec(channel:c,contributorID:"fluid",maximumBytes:4096,pressureGradientTolerance:1e-8)
        let provider:any RuntimeContributorHandling=FluidRuntimeContributors(codec:codec)
        var w=try FluidByteWork(maximumBytes:10000,maximumVisitedBytes:100000)
        let record=try codec.encode(FluidFixtures.state(channel:c,boundary:b),work:&w)
        let evidence=try provider.validate(record,model:model,budget:RuntimeValidationBudget(workUnits:10000,scratchBytes:10000))
        #expect(evidence.workUnitsUsed == codec.encodedSize+codec.schema.id.utf8.count)
        #expect(throws:RuntimeFailure.self) { _=try provider.validate(record,model:model,budget:RuntimeValidationBudget(workUnits:0,scratchBytes:10000)) }
        let unknown=try RuntimeContributorState(id:"another-fluid",category:.integrator,version:1,bytes:record.bytes)
        do throws(RuntimeFailure) { _=try provider.validate(unknown,model:model,budget:RuntimeValidationBudget(workUnits:10000,scratchBytes:10000));Issue.record("Expected binding rejection") }
        catch { #expect(error.code == .incompatibleContinuation) }
    }

    @Test func requiredMigrationExplicitlyRejectsChangedModel() throws {
        let source=try FluidFixtures.model(),target=try FluidFixtures.model(revision:2)
        let transition=try ReferenceModelRevisionUpdater().transition(from:source,to:target,policy:.preserveIfKinematicsUnchanged)
        let channel=try FluidFixtures.channel(model:source.stamp)
        let codec=try FixedFluidContinuationCodec(channel:channel,contributorID:"fluid",maximumBytes:4096,pressureGradientTolerance:1e-8)
        var w=try FluidByteWork(maximumBytes:10000,maximumVisitedBytes:100000)
        let record=try codec.encode(FluidFixtures.state(channel:channel,boundary:FluidFixtures.boundary()),work:&w)
        let provider:any RuntimeContributorHandling=FluidRuntimeContributors(codec:codec)
        do throws(RuntimeFailure) { _=try provider.migrate(record,transition:transition,target:target,budget:RuntimeValidationBudget(workUnits:10000,scratchBytes:10000));Issue.record("Expected unsupported migration") }
        catch { #expect(error.code == .unsupportedDomain) }
    }

    @Test func actualSteadyResultCannotBePublishedAsTransientAdvance() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try FluidRuntimeFixture(),initial=try fixture.accepted(),model=fixture.model
            let boundary=try FluidFixtures.boundary(gradient:-2),policy=try FluidFixtures.policy()
            let op:any FluidTrialOperating=ReferenceFluidTrialOperator(codec:fixture.codec,evolution:SteadyOnlyFluidEvolution())
            do throws(RuntimeFailure) {
                _=try fixture.session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                    var work:NumericalWork;var bytes:FluidByteWork
                    do { work=try FluidFixtures.work();bytes=try FluidByteWork(maximumBytes:10000,maximumVisitedBytes:100000) }
                    catch { throw RuntimeFailure(.invalidInput,message:"Fixture budgets failed.") }
                    _=try op.advance(model:model,boundary:boundary,duration:0.1,policy:policy,trial:&trial,control:&control,numerical:&work,bytes:&bytes)
                    return .accept
                };Issue.record("Expected original history advance rejection")
            } catch { #expect(error.code == .invalidState) }
            #expect(try fixture.accepted() == initial);_=fixture.session.shutdown()
        } else { Issue.record("Runtime fluid history verification requires Runtime availability.") }
    }
}
