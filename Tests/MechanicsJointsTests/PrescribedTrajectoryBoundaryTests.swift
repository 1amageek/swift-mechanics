import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PrescribedTrajectoryBoundaryTests {
    @Test func earliestInternalKnotUsesCompleteInventoryStrictAfterAndInclusiveLimit() throws {
        let first = try PrescribedTrajectoryFixtures.piecewise(frame: "a"), second = try PrescribedTrajectoryFixtures.piecewise(frame: "b",duration: 0.5)
        let program = try PrescribedTrajectoryFixtures.anchor([.piecewise(second),.piecewise(first)])
        let query: any PrescribedTrajectoryBoundaryQuerying = PrescribedTrajectoryBoundaryQuery()
        var work = try PrescribedTrajectoryFixtures.work()
        #expect(program.trajectories[0].frame == first.frame && program.minimumTime == 0 && program.maximumTime == 1)
        for (after,through,expected) in [(0.0,0.49,Optional<Double>.none),(0,0.5,0.5),(0.5,1,1),(1,1,nil)] {
            let result = try OriginalPrescribedTrajectoryBoundaryAcceptance.nextBoundary(program,after: after,through: through,policy: program.policy,query: query,work: &work)
            #expect(result == expected)
        }
        let base = try PrescribedTrajectoryFixtures.base(.piecewise(first))
        #expect(try query.nextBaseBoundary(base,after: 0,through: 1,policy: base.policy,work: &work) == 1)
        #expect(try query.nextBaseBoundary(base,after: 1,through: 2,policy: base.policy,work: &work) == nil)
        let harmonic = try PrescribedTrajectoryFixtures.anchor([.harmonic(PrescribedTrajectoryFixtures.harmonic())])
        let periodicNil = try OriginalPrescribedTrajectoryBoundaryAcceptance.nextBoundary(harmonic,after: 0,through: 8,policy: harmonic.policy,query: query,work: &work)
        #expect(periodicNil == nil)
    }

    @Test func realChangedKnotAndEverySupplierFailurePreserveOriginalBoundaryAndPrefix() throws {
        let law = try PrescribedTrajectoryFixtures.piecewise(), alternateLaw = try PrescribedTrajectoryFixtures.piecewise(duration: 1.5)
        let program = try PrescribedTrajectoryFixtures.anchor([.piecewise(law)]), base = try PrescribedTrajectoryFixtures.base(.piecewise(law))
        let alternate = try PrescribedTrajectoryFixtures.anchor([.piecewise(alternateLaw)]), alternateBase = try PrescribedTrajectoryFixtures.base(.piecewise(alternateLaw))
        for isBase in [false,true] {
            var direct = try PrescribedTrajectoryFixtures.work(), success = try PrescribedTrajectoryFixtures.work()
            if isBase {
                _ = try PrescribedTrajectoryBoundaryQuery().nextBaseBoundary(base,after: 0,through: 2,policy: base.policy,work: &direct)
                _ = try OriginalPrescribedTrajectoryBoundaryAcceptance.nextBaseBoundary(base,after: 0,through: 2,policy: base.policy,query: PrescribedTrajectoryBoundaryQuery(),work: &success)
            } else {
                _ = try PrescribedTrajectoryBoundaryQuery().nextBoundary(program,after: 0,through: 2,policy: program.policy,work: &direct)
                _ = try OriginalPrescribedTrajectoryBoundaryAcceptance.nextBoundary(program,after: 0,through: 2,policy: program.policy,query: PrescribedTrajectoryBoundaryQuery(),work: &success)
            }
            let irreversiblePrefix = success.operations-direct.operations
            for mode in [TrajectoryFaultSupplier.Mode.wrongSource,.resetSuccess,.resetFailure,.knownFailure,.unavailableFailure] {
                let supplier = TrajectoryFaultSupplier(mode: mode,alternate: alternate,alternateBase: alternateBase)
                var work = try PrescribedTrajectoryFixtures.work()
                do throws(PrescribedMotionError) {
                    if isBase { _ = try OriginalPrescribedTrajectoryBoundaryAcceptance.nextBaseBoundary(base,after: 0,through: 2,policy: base.policy,query: supplier,work: &work) }
                    else { _ = try OriginalPrescribedTrajectoryBoundaryAcceptance.nextBoundary(program,after: 0,through: 2,policy: program.policy,query: supplier,work: &work) }
                    Issue.record("Fault boundary accepted")
                } catch {
                    switch mode {
                    case .wrongSource: if case .staleSource = error {} else { Issue.record("Wrong actual knot failure") };#expect(work.operations > irreversiblePrefix)
                    case .resetSuccess,.resetFailure: if case .supplierLedgerReplaced = error {} else { Issue.record("Wrong reset failure") };#expect(error.failedSupplierWorkUnavailable && work.operations == irreversiblePrefix)
                    case .knownFailure: if case .outsideDomain = error {} else { Issue.record("Wrong known boundary failure") };#expect(work.operations == irreversiblePrefix+7 && work.iterations == 1)
                    case .unavailableFailure: if case .supplierWorkUnavailable = error {} else { Issue.record("Wrong unavailable boundary failure") };#expect(error.failedSupplierWorkUnavailable && work.operations == irreversiblePrefix+7)
                    }
                }
            }
        }
    }

    @Test func boundaryTimeDomainCapacityAndLateCancellationAreExplicit() throws {
        let law = try PrescribedTrajectoryFixtures.piecewise(), program = try PrescribedTrajectoryFixtures.anchor([.piecewise(law)])
        let base = try PrescribedTrajectoryFixtures.base(.piecewise(law))
        var work = try PrescribedTrajectoryFixtures.work()
        for (after,through,invalid) in [(Double.nan,1.0,true),(1.0,0.0,true),(-0.1,1.0,false),(0.0,2.1,false)] {
            do throws(PrescribedMotionError) { _ = try PrescribedTrajectoryBoundaryQuery().nextBoundary(program,after: after,through: through,policy: program.policy,work: &work);Issue.record("Invalid boundary interval admitted") }
            catch { switch error { case .invalidInput: #expect(invalid);case .outsideDomain: #expect(!invalid);default: Issue.record("Wrong interval refusal") } }
        }
        var storage = try PrescribedTrajectoryFixtures.work(storage: 1)
        do throws(PrescribedMotionError) { _ = try PrescribedTrajectoryBoundaryQuery().nextBoundary(program,after: 0,through: 1,policy: program.policy,work: &storage);Issue.record("Boundary workspace bound ignored") }
        catch { if case .numerical(.resourceLimit(.scalarStorage,_)) = error { #expect(storage.operations == 0) } else { Issue.record("Wrong boundary capacity failure") } }
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            for isBase in [false,true] {
                let supplier = TrajectoryCancellation(), policy = try PrescribedTrajectoryFixtures.policy(cancelled: { supplier.cancelled() })
                var ledger = try PrescribedTrajectoryFixtures.work()
                do throws(PrescribedMotionError) {
                    if isBase { _ = try OriginalPrescribedTrajectoryBoundaryAcceptance.nextBaseBoundary(base,after: 0,through: 2,policy: policy,query: supplier,work: &ledger) }
                    else { _ = try OriginalPrescribedTrajectoryBoundaryAcceptance.nextBoundary(program,after: 0,through: 2,policy: policy,query: supplier,work: &ledger) }
                    Issue.record("Cancelled boundary published")
                } catch { if case .cancelled = error { #expect(ledger.operations > 0 && supplier.cancelled()) } else { Issue.record("Wrong late boundary cancellation") } }
            }
        }
    }
}
