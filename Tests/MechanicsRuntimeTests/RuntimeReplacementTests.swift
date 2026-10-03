import Testing
import Synchronization
import MechanicsJoints
import MechanicsRuntime
import MechanicsCompiler

@Suite struct RuntimeReplacementTests {
    @Test func changedChartPublishesCompleteContextAndRestartsWithNewHandler() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        let session = try RuntimeFixtures.session()
        _ = try RuntimeFixtures.advance(session)
        let prefix = session.snapshot(), target = try RuntimeFixtures.model(revision: 2, floating: true)
        let config = try emptyConfiguration(session.configuration)
        let handler = ReferenceRuntimeCheckpointHandler(contributors: NoRuntimeContributors(), revisions: ReferenceModelRevisionUpdater())
        let physical = try KinematicState(revision: 2, time: prefix.physical.state.time, q: [1,2,3,-1,0,0,0], v: [1,0,0,0,0,0], acceleration: [0,0,0,0,0,0])
        let changed = try session.replaceModel(RuntimeModelReplacement(expectedSource: prefix.checkpoint, model: target, physical: physical,
            contributors: [], configuration: config, checkpoints: handler))
        #expect(changed.physical.state == physical && changed.physical.stamp == target.stamp)
        #expect(changed.checkpoint.random == prefix.checkpoint.random && changed.checkpoint.acceptedSteps == prefix.checkpoint.acceptedSteps + 1)
        #expect(session.configuration.requiredContributors.isEmpty && session.profile().workload == "floating-after-replacement")
        #expect(session.profile().reservedPhysicalScalars == 19 && prefix.physical.state.q.count == 1)
        let advanced = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try control.beginWorkBlock(units: 1); try trial.setPosition(4, at: 2); try trial.setVelocity(2, at: 5)
            _ = try trial.nextRandom(); try trial.setTime(trial.timeSeconds + 0.5); return .accept
        }
        #expect(advanced.accepted.physical.state.q.count == 7 && advanced.accepted.physical.state.v[5] == 2)
        #expect(advanced.accepted.physical.state.q[2] == 4 && advanced.accepted.checkpoint.contributors.isEmpty)
        #expect(advanced.accepted.checkpoint.random.draws == prefix.checkpoint.random.draws + 1)
        let bytes = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try trial.setPosition(9, at: 0); try trial.setTime(trial.timeSeconds + 1); return .accept
        }
        let restored = try session.restart(bytes, codec: NativeRuntimeCheckpointCodec())
        #expect(restored == advanced.accepted && session.snapshot() == advanced.accepted)
    }
    @Test func invalidTargetsAndStaleCompleteSourcePreserveOldOwner() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        let session = try RuntimeFixtures.session(), target = try RuntimeFixtures.model(revision: 2, floating: true)
        let prefix = session.snapshot(), handler = try RuntimeFixtures.handler(), config = session.configuration
        let wrongSourceState = try KinematicState(revision: 1, time: 0, q: [9], v: [0], acceleration: [0])
        let wrongSource = try RuntimeCheckpoint(model: prefix.checkpoint.model, continuation: prefix.checkpoint.continuation,
            physical: wrongSourceState, contributors: prefix.checkpoint.contributors, random: prefix.checkpoint.random, acceptedSteps: prefix.checkpoint.acceptedSteps)
        let valid = target.descriptor.initialState
        let badShape = try KinematicState(revision: 2, time: 0, q: [0], v: [0], acceleration: [0])
        let badTime = try KinematicState(revision: 2, time: 1, q: valid.q, v: valid.v, acceleration: valid.acceleration)
        let changedCapacity = try RuntimeFixtures.configuration(capacity: RuntimeFixtures.capacity(physical: 101))
        let changedBuild = try RuntimeFixtures.configuration(build: "other-build")
        let records = prefix.checkpoint.contributors
        let cases: [(RuntimeFailureCode, RuntimeCheckpoint, KinematicState, [RuntimeContributorState], RuntimeConfiguration)] = [
            (.incompatibleModel, wrongSource, valid, records, config),
            (.invalidState, prefix.checkpoint, badShape, records, config),
            (.missingContributor, prefix.checkpoint, valid, [], config),
            (.incompatibleModel, prefix.checkpoint, badTime, records, config),
            (.capacityExceeded, prefix.checkpoint, valid, records, changedCapacity),
            (.incompatibleContinuation, prefix.checkpoint, valid, records, changedBuild)
        ]
        for (code, source, state, contributors, configuration) in cases {
            RuntimeFixtures.failure(code) { () throws(RuntimeFailure) in
                _ = try session.replaceModel(RuntimeModelReplacement(expectedSource: source, model: target, physical: state,
                    contributors: contributors, configuration: configuration, checkpoints: handler))
            }
            #expect(session.snapshot() == prefix && session.configuration.requiredContributors == config.requiredContributors)
            #expect(session.profile().reservedPhysicalScalars == 3)
        }
        _ = try RuntimeFixtures.advance(session)
        RuntimeFixtures.failure(.incompatibleModel) { () throws(RuntimeFailure) in
            _ = try session.replaceModel(RuntimeModelReplacement(expectedSource: prefix.checkpoint, model: target,
                physical: valid, contributors: records, configuration: config, checkpoints: handler))
        }
        #expect(session.snapshot().physical.state.q.count == 1 && session.snapshot().checkpoint.acceptedSteps == 1)
    }
    @Test func capacityFailureAndNestedUnknownWorkPreservePrefixAndFlag() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        let config = try RuntimeFixtures.configuration(capacity: RuntimeFixtures.capacity(physical: 3))
        let session = try RuntimeFixtures.session(configuration: config), prefix = session.snapshot(), handler = try RuntimeFixtures.handler()
        let target = try RuntimeFixtures.model(revision: 2, floating: true)
        RuntimeFixtures.failure(.capacityExceeded) { () throws(RuntimeFailure) in
            _ = try session.replaceModel(RuntimeModelReplacement(expectedSource: prefix.checkpoint, model: target,
                physical: target.descriptor.initialState, contributors: prefix.checkpoint.contributors, configuration: config, checkpoints: handler))
        }
        do throws(RuntimeFailure) {
            _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                try control.beginWorkBlock(units: 1); _ = try trial.nextRandom()
                throw RuntimeFailure(.invalidState, message: String(repeating: "x", count: 1001), failedSupplierWorkUnavailable: true)
            }
            Issue.record("Expected bounded nested failure.")
        } catch {
            #expect(error.code == .capacityExceeded && error.failedSupplierWorkUnavailable && error.lastAccepted == prefix)
        }
        #expect(session.snapshot() == prefix)
    }
    @Test func admissionReentryAndOldHandlerRetirementAreOutsideOwnerLock() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        let owner = RuntimeReplacementOwner(), initial = try RuntimeFixtures.model(), config = try RuntimeFixtures.configuration()
        let session = try RuntimeSession(model: initial, configuration: config, initialState: initial.descriptor.initialState,
            contributors: [CounterRuntimeContributors.record(0)], seed: 42,
            checkpoints: RuntimeReplacementHandler(onRetire: { owner.retire() }))
        owner.bind(session)
        let prefix = session.snapshot(), target = try RuntimeFixtures.model(revision: 2)
        let handler = try RuntimeReplacementHandler(onAdmission: { () throws(RuntimeFailure) in
            guard let current = owner.current() else { throw RuntimeFailure(.invalidOwnerAccess, message: "Fixture owner retired before admission.") }
            #expect(current.snapshot() == prefix && current.configuration.requiredContributors == config.requiredContributors)
            RuntimeFixtures.failure(.busy) { () throws(RuntimeFailure) in _ = try RuntimeFixtures.advance(current) }
        })
        let result = try session.replaceModel(RuntimeModelReplacement(expectedSource: prefix.checkpoint, model: target,
            physical: target.descriptor.initialState, contributors: prefix.checkpoint.contributors, configuration: config, checkpoints: handler))
        #expect(owner.evidence().0 == 1 && owner.evidence().1 == result)
        #expect(session.profile().committedTransactions == 1)
    }
    @Test(.timeLimit(.minutes(1))) func concurrentCancelAndShutdownRejectTargetPublication() async throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime OS baseline unavailable."); return }
        for close in [false, true] {
            let releases = Mutex(0), gate = RuntimeBlockingGate()
            let session = try RuntimeFixtures.session(onRelease: { releases.withLock { $0 += 1 } })
            let prefix = session.snapshot(), target = try RuntimeFixtures.model(revision: 2, floating: true)
            let handler = try RuntimeReplacementHandler(onAdmission: { () throws(RuntimeFailure) in try gate.wait() })
            let request = RuntimeModelReplacement(expectedSource: prefix.checkpoint, model: target, physical: target.descriptor.initialState,
                contributors: prefix.checkpoint.contributors, configuration: session.configuration, checkpoints: handler)
            let task = Task.detached { () -> Result<RuntimeAcceptedState, RuntimeFailure> in
                do throws(RuntimeFailure) { return .success(try session.replaceModel(request)) } catch { return .failure(error) }
            }
            defer { gate.open() }; try await gate.waitForEntry()
            #expect(session.snapshot() == prefix && session.profile().reservedPhysicalScalars == 3)
            RuntimeFixtures.failure(.busy) { () throws(RuntimeFailure) in _ = try session.replaceModel(request) }
            if close { #expect(session.shutdown() == .draining) } else { session.cancel() }
            gate.open()
            switch await task.value {
            case .success: Issue.record("Cancelled/closed replacement published.")
            case .failure(let error): #expect(error.code == .cancelled || error.code == .closed); #expect(error.lastAccepted == prefix)
            }
            #expect(session.snapshot() == prefix && session.profile().reservedPhysicalScalars == 3)
            if close { #expect(session.shutdownStatus() == .closed && releases.withLock { $0 } == 1) }
            else { _ = try RuntimeFixtures.advance(session); #expect(session.snapshot().checkpoint.acceptedSteps == 1) }
        }
    }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private func emptyConfiguration(_ source: RuntimeConfiguration) throws -> RuntimeConfiguration {
        try RuntimeConfiguration(continuation: source.continuation, requiredContributors: [], capacity: source.capacity,
            determinism: source.determinism, workload: "floating-after-replacement")
    }
}
