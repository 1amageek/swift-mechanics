import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct GranularRuntimeFailureTests {
    @Test(arguments:[GranularRuntimeSupplierFault.numericalReset,.collisionReset,.contactReset,.supplierReset],[false,true])
    func actualSupplierWorkResetOnSuccessAndFailureRetainsAllKnownPrefixes(fault: GranularRuntimeSupplierFault,fails: Bool) throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime availability missing");return }
        let f=try GranularRuntimeFixture(evolution:GranularRuntimeFaultEvolution(fault,fails:fails));defer { _=f.session.shutdown() }
        let prefix=f.session.snapshot(),model=f.model,operation=f.operation,physics=f.source.physicsBudget
        do throws(RuntimeFailure) {
            _=try f.session.performTrial { (trial: inout RuntimeTrial,control: inout RuntimeStepControl) throws(RuntimeFailure) in
                var work: GranularRuntimeWork
                do { work=try GranularRuntimeFixture.work(physics) } catch { throw RuntimeFailure(.invalidInput,message:"Fixture budgets failed") }
                do throws(RuntimeFailure) { _=try operation.advance(model:model,duration:0.001,trial:&trial,control:&control,work:&work) }
                catch {
                    #expect(work.numerical.operations > 0 && work.collision.operations > 0 && work.contact.operations > 0 && work.suppliers.calls >= 2)
                    #expect(work.workUnits > physics.maximumWorkUnits)
                    throw error
                }
                return .accept
            }
            Issue.record("Actual supplier reset published")
        } catch { #expect(error.code == .invalidContributor && error.failedSupplierWorkUnavailable && error.lastAccepted == prefix) }
        #expect(f.session.snapshot() == prefix && prefix.checkpoint.random.draws == 0)
    }
    @Test(arguments:[GranularRuntimeSupplierFault.failure,.wrongGravity])
    func actualSupplierFailureAndForeignPhysicalResultCannotPublish(fault: GranularRuntimeSupplierFault) throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime availability missing");return }
        let f=try GranularRuntimeFixture(evolution:GranularRuntimeFaultEvolution(fault));defer { _=f.session.shutdown() }
        let prefix=f.session.snapshot()
        do throws(RuntimeFailure) { _=try f.advance();Issue.record("Supplier failure/foreign physics published") }
        catch { #expect(error.code == .invalidContributor && !error.failedSupplierWorkUnavailable && error.lastAccepted == prefix) }
        #expect(f.session.snapshot() == prefix)
    }
    @Test func cancellationAfterRealSupplierStepAndWorkQuantumRefusePublication() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime availability missing");return }
        let flag=GranularRuntimeCancellationFlag(),policy=try GranularRuntimeParticleFixtures.policy(cancel:{flag.cancelled})
        let f=try GranularRuntimeFixture(policy:policy,evolution:GranularRuntimeFaultEvolution(.cancellation,flag:flag));defer { _=f.session.shutdown() }
        let prefix=f.session.snapshot()
        do throws(RuntimeFailure) { _=try f.advance();Issue.record("Cancelled original step published") }
        catch { #expect(error.code == .cancelled && error.lastAccepted == prefix) }
        #expect(flag.cancelled && f.session.snapshot() == prefix)
        let limited=try GranularRuntimeFixture(stepWork:2);defer { _=limited.session.shutdown() }
        let initial=limited.session.snapshot()
        do throws(RuntimeFailure) { _=try limited.advance();Issue.record("Exhausted Runtime quantum published") }
        catch { #expect(error.code == .capacityExceeded && error.lastAccepted == initial) }
        #expect(limited.session.snapshot() == initial)
    }
    @Test func boundedColdReplayCancellationCannotPublishPartialOriginalHistory() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("Runtime availability missing");return }
        let f=try GranularRuntimeFixture();defer { _=f.session.shutdown() };_=try f.advance()
        let flag=GranularRuntimeCancellationFlag();flag.set()
        var work=try GranularRuntimeFixture.work(f.source.physicsBudget,cancel:{flag.cancelled})
        let record=f.session.snapshot().checkpoint.contributors[0],prefix=f.session.snapshot()
        do throws(GranularRuntimeError) { _=try f.journal.decode(record,work:&work);Issue.record("Cancelled cold replay returned history") }
        catch { if case .cancelled=error {} else { Issue.record("Wrong cancellation refusal") } }
        #expect(work.workUnits == 0 && work.numerical.operations == 0 && f.session.snapshot() == prefix)
    }
}
