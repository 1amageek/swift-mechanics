import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ContactSupplierTests {
    @Test(arguments:[ContactFaultSupplier.Mode.wrongSource,.failedPrefix,.resetSuccess,.resetFailure,.changedBudget,.exhaust])
    func realDelegatedSupplierFailuresKeepKnownPrefix(_ mode: ContactFaultSupplier.Mode) throws {
        let pair=try ContactDerivativeFixtures.pair(), input=try ContactDerivativeFixtures.input()
        let history=try ContactDerivativeFixtures.history(pair,input:input), policy=try ContactDerivativeFixtures.policy()
        let direction=try ContactDirection(separation:-0.001,relativeVelocity:.zero)
        var work=try ContactDerivativeFixtures.work(20_000)
        do {
            _=try ExactContactDifferentiator(laws:ContactFaultSupplier(mode:mode)).contact(input:input,pair:pair,accepted:history,direction:direction,policy:policy,work:&work)
            Issue.record("Faulty supplier accepted")
        } catch {
            switch (mode,error) {
            case (.wrongSource,.primalMismatch): #expect(work.operations > 8000)
            case (.failedPrefix,.law(.normalDomain)): #expect(work.operations > 4000)
            case (.resetSuccess,.invalidSupplierLedger(let unavailable)), (.resetFailure,.invalidSupplierLedger(let unavailable)), (.changedBudget,.invalidSupplierLedger(let unavailable)):
                #expect(unavailable && work.operations < 1000)
            case (.exhaust,.law(.resourceLimit)): #expect(work.operations == work.budget.operations)
            default: throw error
            }
        }
        #expect(work.operations <= work.budget.operations && history.sequence == 0)
    }
    @Test(arguments:[ContactFaultSupplier.Mode.cancelSuccess,.cancelFailure])
    func actualTaskCancellationAfterCallbackPreservesExecutedSupplierPrefix(_ mode: ContactFaultSupplier.Mode) async throws {
        let pair=try ContactDerivativeFixtures.pair(), input=try ContactDerivativeFixtures.input()
        let history=try ContactDerivativeFixtures.history(pair,input:input), policy=try ContactDerivativeFixtures.policy()
        let direction=try ContactDirection(separation:0,relativeVelocity:.zero)
        let initial=try ContactDerivativeFixtures.work()
        let task=Task {
            var work=initial
            do throws(ContactDerivativeError) { _=try ExactContactDifferentiator(laws:ContactFaultSupplier(mode:mode)).contact(input:input,pair:pair,accepted:history,direction:direction,policy:policy,work:&work); return (false,work.operations) }
            catch { if case .cancelled=error { return (true,work.operations) }; return (false,work.operations) }
        }
        let result=await task.value
        #expect(result.0 && result.1 > 4000 && result.1 < initial.budget.operations)
    }
    @Test func capacityAndPolicyCancellationDoNotCallSupplier() throws {
        let pair=try ContactDerivativeFixtures.pair(), input=try ContactDerivativeFixtures.input()
        let history=try ContactDerivativeFixtures.history(pair,input:input), direction=try ContactDirection(separation:0,relativeVelocity:.zero)
        let policy=try ContactDerivativeFixtures.policy(cancelled:{ true })
        var work=try ContactDerivativeFixtures.work()
        do { _=try ExactContactDifferentiator().contact(input:input,pair:pair,accepted:history,direction:direction,policy:policy,work:&work); Issue.record("Cancellation ignored") }
        catch { guard case .cancelled=error else { throw error } }
        #expect(work.operations == 0)
        let live=try ContactDerivativeFixtures.policy()
        var small=try ContactDerivativeFixtures.work(10)
        do { _=try ExactContactDifferentiator().contact(input:input,pair:pair,accepted:history,direction:direction,policy:live,work:&small); Issue.record("Budget ignored") }
        catch { guard case .law(.resourceLimit)=error else { throw error } }
        #expect(small.operations == 0)
    }
    @Test func impactRejectsRealDifferentEnergySource() throws {
        let pair=try ContactDerivativeFixtures.pair(.hertz(coefficient:1000,effectiveRadius:1,maximumPenetration:0.5,maximumNormalSpeed:100),loss:.separateImpact(restitution:0.6,thresholdSpeed:1))
        let direction=try ContactImpactDirection(approachSpeed:0.3,incomingNormalEnergy:-0.5), policy=try ContactDerivativeFixtures.policy()
        var work=try ContactDerivativeFixtures.work()
        do { _=try ExactContactDifferentiator(impacts:ImpactSourceSupplier()).impact(pair:pair,approachSpeed:2,incomingNormalEnergy:4,direction:direction,policy:policy,work:&work); Issue.record("Different incoming energy accepted") }
        catch { guard case .primalMismatch=error else { throw error } }
        #expect(work.operations > 256)
    }
    @Test func acceptedHistoryReplayUsesUnchangedPrimalAuthority() throws {
        let pair=try ContactDerivativeFixtures.pair(), input=try ContactDerivativeFixtures.input()
        let history=try ContactDerivativeFixtures.history(pair,input:input), direction=try ContactDirection(separation:0.001,relativeVelocity:.zero)
        let policy=try ContactDerivativeFixtures.policy(); var a=try ContactDerivativeFixtures.work(), b=try ContactDerivativeFixtures.work()
        let service: any ContactDifferentiating=ExactContactDifferentiator()
        let x=try service.contact(input:input,pair:pair,accepted:history,direction:direction,policy:policy,work:&a)
        let y=try service.contact(input:input,pair:pair,accepted:history,direction:direction,policy:policy,work:&b)
        #expect(x.primal.trialHistory == y.primal.trialHistory && x.compressiveNormalForce == y.compressiveNormalForce && a.operations == b.operations)
        #expect(history.sequence == 0 && history.timeSeconds == 0)
    }
}
