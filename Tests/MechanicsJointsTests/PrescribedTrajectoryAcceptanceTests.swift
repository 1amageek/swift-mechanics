import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PrescribedTrajectoryAcceptanceTests {
    @Test func originalAuthorityRejectsRealChangedCoefficientDomainKindFrameChartAndTime() throws {
        let harmonic = try PrescribedTrajectoryFixtures.harmonic()
        let program = try PrescribedTrajectoryFixtures.anchor([.harmonic(harmonic)])
        let base = try PrescribedTrajectoryFixtures.base(.harmonic(harmonic))
        let alternatives: [PrescribedTrajectory] = [.harmonic(try PrescribedTrajectoryFixtures.harmonic(phase: 0.31)),
            .harmonic(try PrescribedTrajectoryFixtures.harmonic(maximumTime: 7)),
            .harmonic(try PrescribedTrajectoryFixtures.harmonic(frame: "other")),
            .quadratic(try PrescribedBaseMotionFixtures.law())]
        var work = try PrescribedTrajectoryFixtures.work()
        for trajectory in alternatives {
            let changed = try PrescribedTrajectoryFixtures.anchor([trajectory])
            let changedBase = try PrescribedTrajectoryFixtures.base(trajectory)
            let anchorSample = try AnalyticPrescribedTrajectorySampler().sample(changed,time: 0,policy: changed.policy,work: &work)
            let baseSample = try AnalyticPrescribedBaseTrajectorySampler().sampleBase(changedBase,time: 0,policy: changedBase.policy,work: &work)
            do throws(PrescribedMotionError) { _ = try OriginalPrescribedTrajectoryAcceptance.validated(anchorSample,program: program,time: 0,policy: program.policy,work: &work);Issue.record("Changed trajectory source accepted") }
            catch { if case .staleSource = error {} else { Issue.record("Wrong original anchor failure") } }
            do throws(PrescribedMotionError) { _ = try OriginalPrescribedBaseTrajectoryAcceptance.validated(baseSample,program: base,time: 0,policy: base.policy,work: &work);Issue.record("Changed base source accepted") }
            catch { if case .staleSource = error {} else { Issue.record("Wrong original base failure") } }
        }
        let planar = try PrescribedTrajectoryFixtures.base(.harmonic(PrescribedTrajectoryFixtures.harmonic(planar: true)),planar: true)
        let planarSample = try AnalyticPrescribedBaseTrajectorySampler().sampleBase(planar,time: 0,policy: planar.policy,work: &work)
        do throws(PrescribedMotionError) { _ = try OriginalPrescribedBaseTrajectoryAcceptance.validated(planarSample,program: base,time: 0,policy: base.policy,work: &work);Issue.record("Changed chart accepted") }
        catch { if case .staleSource = error {} else { Issue.record("Wrong chart source failure") } }
        let source = try AnalyticPrescribedTrajectorySampler().sample(program,time: 0.5,policy: program.policy,work: &work)
        do throws(PrescribedMotionError) { _ = try OriginalPrescribedTrajectoryAcceptance.validated(source,program: program,time: 0.6,policy: program.policy,work: &work);Issue.record("Changed time accepted") }
        catch { if case .staleSource = error {} else { Issue.record("Wrong time source failure") } }
    }

    @Test func bothSamplerPortsPreserveSeedAndKnownFailurePrefixOnEveryTerminalPath() throws {
        let law = try PrescribedTrajectoryFixtures.harmonic()
        let program = try PrescribedTrajectoryFixtures.anchor([.harmonic(law)])
        let base = try PrescribedTrajectoryFixtures.base(.harmonic(law))
        let alternate = try PrescribedTrajectoryFixtures.anchor([.harmonic(PrescribedTrajectoryFixtures.harmonic(phase: 0.31))])
        let alternateBase = try PrescribedTrajectoryFixtures.base(alternate.trajectories[0])
        var preparation = try PrescribedTrajectoryFixtures.work()
        let anchorSample = try AnalyticPrescribedTrajectorySampler().sample(program,time: 0.5,policy: program.policy,work: &preparation)
        let baseSample = try AnalyticPrescribedBaseTrajectorySampler().sampleBase(base,time: 0.5,policy: base.policy,work: &preparation)
        var anchorValidation = try PrescribedTrajectoryFixtures.work(), baseValidation = try PrescribedTrajectoryFixtures.work()
        _ = try OriginalPrescribedTrajectoryAcceptance.validated(anchorSample,program: program,time: 0.5,policy: program.policy,work: &anchorValidation)
        _ = try OriginalPrescribedBaseTrajectoryAcceptance.validated(baseSample,program: base,time: 0.5,policy: base.policy,work: &baseValidation)
        for isBase in [false,true] {
            let baseline = isBase ? baseValidation : anchorValidation
            for mode in [TrajectoryFaultSupplier.Mode.wrongSource,.resetSuccess,.resetFailure,.knownFailure,.unavailableFailure] {
                let supplier = TrajectoryFaultSupplier(mode: mode,alternate: alternate,alternateBase: alternateBase)
                var work = try PrescribedTrajectoryFixtures.work()
                do throws(PrescribedMotionError) {
                    if isBase { _ = try OriginalPrescribedBaseTrajectoryAcceptance.sealedBaseMotion(base,time: 0.5,policy: base.policy,sampler: supplier,work: &work) }
                    else { _ = try OriginalPrescribedTrajectoryAcceptance.sealedMotion(program,time: 0.5,policy: program.policy,sampler: supplier,work: &work) }
                    Issue.record("Terminal supplier fault accepted")
                } catch {
                    switch mode {
                    case .wrongSource: if case .staleSource = error {} else { Issue.record("Wrong delegated source failure") };#expect(work.operations > baseline.operations)
                    case .resetSuccess,.resetFailure:
                        if case .supplierLedgerReplaced = error {} else { Issue.record("Wrong reset refusal") }
                        #expect(error.failedSupplierWorkUnavailable && work.operations == baseline.operations+2 && work.iterations == 0)
                    case .knownFailure:
                        if case .outsideDomain = error {} else { Issue.record("Wrong known failure") }
                        #expect(!error.failedSupplierWorkUnavailable && work.operations == baseline.operations+9 && work.iterations == 1)
                    case .unavailableFailure:
                        if case .supplierWorkUnavailable = error {} else { Issue.record("Wrong unavailable failure") }
                        #expect(error.failedSupplierWorkUnavailable && work.operations == baseline.operations+9)
                    }
                    #expect(work.operations <= work.budget.arithmeticOperations && work.peakScalarStorage <= work.budget.scalarStorage)
                }
            }
        }
    }

    @Test func boundsBeforeSamplingAndIterationExhaustionPreserveActualPrefix() throws {
        let law = try PrescribedTrajectoryFixtures.harmonic(), program = try PrescribedTrajectoryFixtures.anchor([.harmonic(law)])
        let base = try PrescribedTrajectoryFixtures.base(.harmonic(law))
        let supplier = TrajectoryFaultSupplier(mode: .knownFailure,alternate: program,alternateBase: base)
        for storage in [false,true] {
            var work = try PrescribedTrajectoryFixtures.work(storage: storage ? 1 : 100000,operations: storage ? 10000000 : 1)
            do throws(PrescribedMotionError) { _ = try OriginalPrescribedTrajectoryAcceptance.sealedMotion(program,time: 0.5,policy: program.policy,sampler: supplier,work: &work);Issue.record("Caller bound exceeded") }
            catch {
                if case .numerical(.resourceLimit(let resource,_)) = error { #expect(resource == (storage ? .scalarStorage : .arithmeticOperations) && work.operations == 0) }
                else { Issue.record("Wrong caller resource failure") }
            }
        }
        var validation = try PrescribedTrajectoryFixtures.work()
        var sampleWork = try PrescribedTrajectoryFixtures.work()
        let sample = try AnalyticPrescribedTrajectorySampler().sample(program,time: 0.5,policy: program.policy,work: &sampleWork)
        _ = try OriginalPrescribedTrajectoryAcceptance.validated(sample,program: program,time: 0.5,policy: program.policy,work: &validation)
        var zeroIterations = try PrescribedTrajectoryFixtures.work(iterations: 0)
        do throws(PrescribedMotionError) { _ = try OriginalPrescribedTrajectoryAcceptance.sealedMotion(program,time: 0.5,policy: program.policy,sampler: supplier,work: &zeroIterations);Issue.record("Iteration bound exceeded") }
        catch { if case .numerical(.resourceLimit(.iterations,_)) = error { #expect(zeroIterations.operations == validation.operations+9 && zeroIterations.iterations == 0) } else { Issue.record("Wrong iteration failure") } }
        let small = try PrescribedTrajectoryFixtures.policy(metadata: 10)
        var work = try PrescribedTrajectoryFixtures.work()
        do throws(PrescribedMotionError) { _ = try PrescribedTrajectoryProgram(trajectories: [.harmonic(law)],policy: small,work: &work);Issue.record("Metadata bound ignored") }
        catch { if case .capacityExceeded = error {} else { Issue.record("Wrong metadata failure") } }
        let piecewise = try PrescribedTrajectoryFixtures.piecewise(), segments = try PrescribedTrajectoryFixtures.policy(segments: 1)
        do throws(PrescribedMotionError) { _ = try PrescribedTrajectoryProgram(trajectories: [.piecewise(piecewise)],policy: segments,work: &work);Issue.record("Segment bound ignored") }
        catch { if case .capacityExceeded = error {} else { Issue.record("Wrong segment capacity failure") } }
        let count = try PrescribedTrajectoryFixtures.policy(samples: 1)
        let other = try PrescribedTrajectoryFixtures.harmonic(frame: "second")
        do throws(PrescribedMotionError) { _ = try PrescribedTrajectoryProgram(trajectories: [.harmonic(law),.harmonic(other)],policy: count,work: &work);Issue.record("Inventory bound ignored") }
        catch { if case .capacityExceeded = error {} else { Issue.record("Wrong sample capacity failure") } }
    }

    @Test func fullInventoryOutcomeValidationCannotUseTheFormerLinearAllowance() throws {
        let first = try PrescribedTrajectoryFixtures.harmonic(frame: "first")
        let second = try PrescribedTrajectoryFixtures.harmonic(frame: "second")
        let program = try PrescribedTrajectoryFixtures.anchor([.harmonic(second),.harmonic(first)])
        // This was the new path's insufficient linear allowance before the owned review finding.
        // The original sealed outcome still checks every frame pair; its work must be admitted before publication.
        let formerAllowance = program.metadata.utf8.count + 2048*program.trajectories.count
        var bounded = try PrescribedTrajectoryFixtures.work(operations: formerAllowance)
        do throws(PrescribedMotionError) {
            _ = try AnalyticPrescribedTrajectorySampler().sample(program,time: 0.5,policy: program.policy,work: &bounded)
            Issue.record("Full inventory published under the insufficient original comparison allowance")
        } catch {
            if case .numerical(.resourceLimit(.arithmeticOperations,_)) = error { #expect(bounded.operations == 0) }
            else { Issue.record("Wrong original all-pair work refusal") }
        }
        var sufficient = try PrescribedTrajectoryFixtures.work()
        let actual = try AnalyticPrescribedTrajectorySampler().sample(program,time: 0.5,policy: program.policy,work: &sufficient)
        #expect(actual.anchors.count == 2 && actual.anchors[0].frame == first.frame && actual.anchors[1].frame == second.frame)
        #expect(sufficient.operations > formerAllowance && sufficient.operations <= sufficient.budget.arithmeticOperations)
    }

    @Test func lateCancellationRejectsRealSamplerResultsOnBothPorts() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let law = try PrescribedTrajectoryFixtures.harmonic()
            let program = try PrescribedTrajectoryFixtures.anchor([.harmonic(law)]), base = try PrescribedTrajectoryFixtures.base(.harmonic(law))
            for isBase in [false,true] {
                let supplier = TrajectoryCancellation()
                let policy = try PrescribedTrajectoryFixtures.policy(cancelled: { supplier.cancelled() })
                var work = try PrescribedTrajectoryFixtures.work()
                do throws(PrescribedMotionError) {
                    if isBase { _ = try OriginalPrescribedBaseTrajectoryAcceptance.sealedBaseMotion(base,time: 0.5,policy: policy,sampler: supplier,work: &work) }
                    else { _ = try OriginalPrescribedTrajectoryAcceptance.sealedMotion(program,time: 0.5,policy: policy,sampler: supplier,work: &work) }
                    Issue.record("Late cancelled sample published")
                } catch { if case .cancelled = error { #expect(supplier.cancelled() && work.operations > 0 && work.operations <= work.budget.arithmeticOperations) } else { Issue.record("Wrong late cancellation failure") } }
            }
        }
    }
}
