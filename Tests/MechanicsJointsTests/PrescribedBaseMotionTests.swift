import Foundation
import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PrescribedBaseMotionTests {
    @Test func spatialRootUsesOriginalNoncommutingWorldLawAndBodyChart() throws {
        let program = try PrescribedBaseMotionFixtures.program()
        var work = try PrescribedBaseMotionFixtures.work()
        let sampler: any PrescribedBaseMotionSampling = AnalyticPrescribedBaseMotionSampler()
        let initial = try sampler.sampleBase(program, time: 0, policy: program.policy, work: &work)
        #expect(program.layout == .spatialFloating)
        #expect(initial.frame == program.law.frame && initial.worldFrame == program.law.parentFrame)
        #expect(initial.q[3].bitPattern == program.law.initialPose.rotation.w.bitPattern)
        #expect(initial.q[4].bitPattern == program.law.initialPose.rotation.x.bitPattern)
        let t = 0.7, theta = 0.2 * t + 0.15 * t * t, omega = 0.2 + 0.3 * t
        let result = try OriginalPrescribedBaseMotionAcceptance.sealedBaseMotion(program, time: t,
            policy: program.policy, sampler: sampler, work: &work)
        let cosine = cos(theta / 2), sine = sin(theta / 2), c = cos(0.2), s = sin(0.2)
        let expectedQ = [1 + 0.4 * t + 0.15 * t * t, 2 - 0.2 * t + 0.1 * t * t, 3 + 0.1 * t - 0.05 * t * t,
            -cosine * c, -cosine * s, -sine * s, -sine * c]
        let expectedV = [0.4 + 0.3 * t, -0.2 + 0.2 * t, 0.1 - 0.1 * t, 0, sin(0.4) * omega, cos(0.4) * omega]
        let expectedA = [0.3, 0.2, -0.1, 0, sin(0.4) * 0.3, cos(0.4) * 0.3]
        let expectedRate = [expectedV[0], expectedV[1], expectedV[2], 0.5 * omega * sine * c,
            0.5 * omega * sine * s, -0.5 * omega * cosine * s, -0.5 * omega * cosine * c]
        #expect(result.q.count == 7 && result.v.count == 6 && result.a.count == 6)
        for i in expectedQ.indices { #expect(abs(result.q[i] - expectedQ[i]) < 2e-14); #expect(abs(result.coordinateRate[i] - expectedRate[i]) < 2e-14) }
        for i in expectedV.indices { #expect(abs(result.v[i] - expectedV[i]) < 2e-14); #expect(abs(result.a[i] - expectedA[i]) < 2e-14) }
        var tangent = 0.0
        for i in 3..<7 { tangent += result.q[i] * result.coordinateRate[i] }
        #expect(abs(tangent) < 1e-14)
        let h = 1e-5
        let before = try sampler.sampleBase(program, time: t - h, policy: program.policy, work: &work)
        let after = try sampler.sampleBase(program, time: t + h, policy: program.policy, work: &work)
        for i in result.q.indices { #expect(abs((after.q[i] - before.q[i]) / (2 * h) - result.coordinateRate[i]) < 2e-9) }
        for i in result.v.indices { #expect(abs((after.v[i] - before.v[i]) / (2 * h) - result.a[i]) < 2e-9) }
    }

    @Test func planarRootRetainsUnwrappedAngleAndSignedAxis() throws {
        let program = try PrescribedBaseMotionFixtures.program(planar: true)
        var work = try PrescribedBaseMotionFixtures.work()
        let result = try AnalyticPrescribedBaseMotionSampler().sampleBase(program, time: 6, policy: program.policy, work: &work)
        #expect(result.q.count == 3 && result.v.count == 3 && result.a.count == 3)
        #expect(abs(result.q[2] - 7) < 2e-14 && result.q[2] > .pi)
        #expect(abs(result.v[2] - 2) < 1e-14 && result.a[2] == 0.3)
        #expect(result.coordinateRate == result.v)
        let source = program.law
        let reversed = try AnalyticPrescribedMotion(frame: source.frame, parentFrame: source.parentFrame, referenceTime: source.referenceTime,
            initialPose: source.initialPose, translationRate: source.translationRate, translationAcceleration: source.translationAcceleration,
            rotationAxis: Vector3(0, 0, -1), angularRate: source.angularRate, angularAcceleration: source.angularAcceleration,
            minimumTime: source.minimumTime, maximumTime: source.maximumTime, maximumIdentifierBytes: 100)
        let opposite = try PrescribedBaseMotionProgram(law: reversed, layout: .planarFloating, policy: program.policy, work: &work)
        let negative = try AnalyticPrescribedBaseMotionSampler().sampleBase(opposite, time: 6, policy: opposite.policy, work: &work)
        #expect(abs(negative.q[2] + 6.2) < 2e-14 && abs(negative.v[2] + 2) < 1e-14 && negative.a[2] == -0.3)
    }

    @Test func exactOriginalAcceptanceRejectsChangedLawFrameChartAndTime() throws {
        let program = try PrescribedBaseMotionFixtures.program()
        let alternatives = [try PrescribedBaseMotionFixtures.program(rate: 0.21),
            try PrescribedBaseMotionFixtures.program(frame: "otherRoot"), try PrescribedBaseMotionFixtures.program(maximumTime: 7),
            try PrescribedBaseMotionFixtures.program(planar: true), try PrescribedBaseMotionFixtures.program(worldFrame: "otherWorld")]
        for alternate in alternatives {
            var work = try PrescribedBaseMotionFixtures.work()
            let supplied = try AnalyticPrescribedBaseMotionSampler().sampleBase(alternate, time: 0.5, policy: alternate.policy, work: &work)
            do throws(PrescribedMotionError) {
                _ = try OriginalPrescribedBaseMotionAcceptance.validated(supplied, program: program, time: 0.5, policy: program.policy, work: &work)
                Issue.record("Changed canonical source accepted")
            } catch { if case .staleSource = error {} else { Issue.record("Wrong original source failure: \(error)") } }
        }
        var work = try PrescribedBaseMotionFixtures.work()
        let source = try AnalyticPrescribedBaseMotionSampler().sampleBase(program, time: 0.5, policy: program.policy, work: &work)
        do throws(PrescribedMotionError) {
            _ = try OriginalPrescribedBaseMotionAcceptance.validated(source, program: program, time: 0.6, policy: program.policy, work: &work)
            Issue.record("Wrong time accepted")
        } catch { if case .staleSource = error {} else { Issue.record("Wrong time failure") } }
    }

    @Test func chartPlaneFrameDomainAndMetadataCapacityFailExplicitly() throws {
        let spatial = try PrescribedBaseMotionFixtures.law()
        let planar = try PrescribedBaseMotionFixtures.law(planar: true)
        let policy = try PrescribedBaseMotionFixtures.policy()
        let bodyID = try EntityID(kind: .body, key: "root")
        var work = try PrescribedBaseMotionFixtures.work()
        do throws(PrescribedMotionError) { _ = try PrescribedBaseMotionProgram(law: spatial, layout: .fixed, policy: policy, work: &work); Issue.record("Fixed base admitted") }
        catch { if case .unsupportedChart = error {} else { Issue.record("Wrong chart failure") } }
        do throws(PrescribedMotionError) { _ = try PrescribedBaseMotionProgram(law: spatial, layout: .planarFloating, policy: policy, work: &work); Issue.record("Spatial law projected to plane") }
        catch { if case .nonPlanarMotion = error {} else { Issue.record("Wrong plane failure") } }
        do throws(PrescribedMotionError) {
            _ = try AnalyticPrescribedMotion(frame: bodyID, parentFrame: planar.parentFrame,
                referenceTime: 0, initialPose: planar.initialPose, translationRate: planar.translationRate,
                translationAcceleration: planar.translationAcceleration, rotationAxis: .unitZ, angularRate: 0.2,
                angularAcceleration: 0.3, minimumTime: -1, maximumTime: 8, maximumIdentifierBytes: 100)
            Issue.record("Body ID substituted for frame")
        } catch { if case .invalidFrame = error {} else { Issue.record("Wrong frame failure") } }
        do throws(PrescribedMotionError) {
            _ = try AnalyticPrescribedMotion(frame: planar.frame, parentFrame: planar.parentFrame,
                referenceTime: 0, initialPose: planar.initialPose, translationRate: planar.translationRate,
                translationAcceleration: planar.translationAcceleration, rotationAxis: .zero, angularRate: 0.2,
                angularAcceleration: 0.3, minimumTime: -1, maximumTime: 8, maximumIdentifierBytes: 100)
            Issue.record("Invalid analytic axis accepted")
        } catch { if case .invalidAxis = error {} else { Issue.record("Wrong law-axis failure") } }
        do throws(PrescribedMotionError) {
            _ = try AnalyticPrescribedMotion(frame: planar.frame, parentFrame: planar.parentFrame,
                referenceTime: 0, initialPose: planar.initialPose, translationRate: planar.translationRate,
                translationAcceleration: planar.translationAcceleration, rotationAxis: .unitZ, angularRate: .nan,
                angularAcceleration: 0.3, minimumTime: -1, maximumTime: 8, maximumIdentifierBytes: 100)
            Issue.record("Nonfinite analytic coefficient accepted")
        } catch { if case .invalidInput = error {} else { Issue.record("Wrong law-coefficient failure") } }
        let small = try PrescribedMotionPolicy(maximumSamples: 1, maximumIdentifierBytes: 100, maximumMetadataBytes: 10)
        do throws(PrescribedMotionError) { _ = try PrescribedBaseMotionProgram(law: planar, layout: .planarFloating, policy: small, work: &work); Issue.record("Metadata bound ignored") }
        catch { if case .capacityExceeded = error {} else { Issue.record("Wrong metadata failure") } }
        let program = try PrescribedBaseMotionFixtures.program()
        for time in [Double.nan, 8.1] {
            do throws(PrescribedMotionError) { _ = try AnalyticPrescribedBaseMotionSampler().sampleBase(program, time: time, policy: policy, work: &work); Issue.record("Invalid time admitted") }
            catch {
                switch error { case .invalidInput: #expect(time.isNaN); case .outsideDomain: #expect(time == 8.1); default: Issue.record("Wrong domain failure") }
            }
        }
    }

    @Test func opaqueSupplierSourceResetAndFailurePreserveKnownPrefix() throws {
        let program = try PrescribedBaseMotionFixtures.program(), alternate = try PrescribedBaseMotionFixtures.program(rate: 0.21)
        var baseline = try PrescribedBaseMotionFixtures.work()
        let original = try AnalyticPrescribedBaseMotionSampler().sampleBase(program, time: 0.5, policy: program.policy, work: &baseline)
        var validation = try PrescribedBaseMotionFixtures.work()
        _ = try OriginalPrescribedBaseMotionAcceptance.validated(original, program: program, time: 0.5, policy: program.policy, work: &validation)
        let modes: [BaseMotionFaultSupplier.Mode] = [.wrongSource, .resetSuccess, .resetFailure, .knownFailure, .unavailableFailure]
        for mode in modes {
            var work = try PrescribedBaseMotionFixtures.work()
            do throws(PrescribedMotionError) {
                _ = try OriginalPrescribedBaseMotionAcceptance.sealedBaseMotion(program, time: 0.5, policy: program.policy,
                    sampler: BaseMotionFaultSupplier(mode: mode, alternate: alternate), work: &work)
                Issue.record("Fault supplier accepted")
            } catch {
                switch mode {
                case .wrongSource: if case .staleSource = error {} else { Issue.record("Wrong source failure") }; #expect(work.operations > validation.operations)
                case .resetSuccess, .resetFailure:
                    if case .supplierLedgerReplaced = error {} else { Issue.record("Wrong reset failure") }
                    #expect(error.failedSupplierWorkUnavailable && work.operations == validation.operations + 2)
                case .knownFailure:
                    if case .outsideDomain = error {} else { Issue.record("Wrong known failure") }
                    #expect(!error.failedSupplierWorkUnavailable && work.operations == validation.operations + 9 && work.iterations == 1)
                case .unavailableFailure:
                    if case .supplierWorkUnavailable = error {} else { Issue.record("Wrong unknown failure") }
                    #expect(error.failedSupplierWorkUnavailable && work.operations == validation.operations + 9)
                }
            }
        }
    }

    @Test func boundedWorkAndLateCancellationCannotPublish() throws {
        let program = try PrescribedBaseMotionFixtures.program()
        for storage in [false, true] {
            var work = try PrescribedBaseMotionFixtures.work(storage: storage ? 255 : 10000, operations: storage ? 100000 : 1)
            do throws(PrescribedMotionError) { _ = try AnalyticPrescribedBaseMotionSampler().sampleBase(program, time: 0.5, policy: program.policy, work: &work); Issue.record("Bound ignored") }
            catch { if case .numerical(.resourceLimit(let resource, _)) = error { #expect(resource == (storage ? .scalarStorage : .arithmeticOperations)) } else { Issue.record("Wrong work failure") } }
        }
        let cancelled = try PrescribedBaseMotionFixtures.policy(cancelled: { true })
        var work = try PrescribedBaseMotionFixtures.work()
        do throws(PrescribedMotionError) { _ = try AnalyticPrescribedBaseMotionSampler().sampleBase(program, time: 0.5, policy: cancelled, work: &work); Issue.record("Cancellation ignored") }
        catch { if case .cancelled = error { #expect(work.operations == 0) } else { Issue.record("Wrong cancellation failure") } }
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) {
            let supplier = BaseMotionCancellation()
            let late = try PrescribedBaseMotionFixtures.policy(cancelled: { supplier.cancelled() })
            var ledger = try PrescribedBaseMotionFixtures.work()
            do throws(PrescribedMotionError) {
                _ = try OriginalPrescribedBaseMotionAcceptance.sealedBaseMotion(program, time: 0.5, policy: late, sampler: supplier, work: &ledger)
                Issue.record("Late cancellation published")
            } catch { if case .cancelled = error { #expect(ledger.operations > 0 && ledger.operations <= ledger.budget.arithmeticOperations) } else { Issue.record("Wrong late cancellation failure") } }
        }
    }
}
