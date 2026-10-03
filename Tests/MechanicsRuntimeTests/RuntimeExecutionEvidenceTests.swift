import Testing
import MechanicsRuntime

@Suite struct RuntimeExecutionEvidenceTests {
    @Test(.timeLimit(.minutes(1))) func parallelBatchMatchesSequentialIndependentWorlds() async throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let model = try RuntimeFixtures.model(), config = try RuntimeFixtures.configuration()
        let factory = try IndependentRuntimeWorldFactory(checkpoints: RuntimeFixtures.handler())
        let parallel = try factory.create(model: model, configuration: config, initialState: model.descriptor.initialState,
            contributors: [CounterRuntimeContributors.record(0)], rootSeed: 9, count: 4)
        let sequential = try factory.create(model: model, configuration: config, initialState: model.descriptor.initialState,
            contributors: [CounterRuntimeContributors.record(0)], rootSeed: 9, count: 4)
        for index in sequential.indices {
            #expect(sequential[index].snapshot().checkpoint.random.seed == RuntimeRandomState.worldSeed(rootSeed: 9, index: UInt64(index)))
            for _ in 0..<8 { _ = try RuntimeFixtures.advance(sequential[index]) }
        }
        let results = try await withThrowingTaskGroup(of: (Int,RuntimeAcceptedState).self) { group in
            for index in parallel.indices {
                let session = parallel[index]
                group.addTask { for _ in 0..<8 { _ = try RuntimeFixtures.advance(session) }; return (index,session.snapshot()) }
            }
            var results: [(Int,RuntimeAcceptedState)] = []
            for try await result in group { results.append(result) }; return results
        }
        for (index, result) in results { #expect(result == sequential[index].snapshot()) }
        #expect(parallel[0].snapshot().checkpoint.random.seed != parallel[1].snapshot().checkpoint.random.seed)
        _ = try RuntimeFixtures.advance(parallel[0])
        #expect(parallel[1].snapshot() == sequential[1].snapshot())
        RuntimeFixtures.failure(.capacityExceeded) { () throws(RuntimeFailure) in
            _ = try factory.create(model: model, configuration: config, initialState: model.descriptor.initialState,
                contributors: [], rootSeed: 9, count: 9)
        }
    }
    @Test func strongerDeterminismAndUnmeasuredProfileFailExplicitly() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let model = try RuntimeFixtures.model(), handler = try RuntimeFixtures.handler(), records = try [CounterRuntimeContributors.record(0)]
        for tier in [RuntimeDeterminismTier.numericalCrossPlatformEquivalence, .bitwisePortability] {
            let config = try RuntimeFixtures.configuration(tier: tier)
            RuntimeFixtures.failure(.unsupportedDeterminism) { () throws(RuntimeFailure) in
                _ = try RuntimeFixtures.Session(model: model, configuration: config, initialState: model.descriptor.initialState, contributors: records, seed: 0, checkpoints: handler)
            }
        }
        let session = try RuntimeFixtures.session(); _ = try RuntimeFixtures.advance(session)
        let profile = session.profile()
        #expect(profile.workload == "hinge-counter-rng" && profile.committedTransactions == 1)
        #expect(profile.physicalScalarCopyUpperBoundPerBufferDetachment == model.tree.layout.positionCount + 2 * model.tree.layout.velocityCount)
        if case .unavailable = profile.duration(for: .solving) {} else { Issue.record("Unmeasured solver timing was fabricated.") }
        RuntimeFixtures.failure(.profilingUnavailable) { () throws(RuntimeFailure) in try profile.requireMeasuredEndToEndProfile() }
    }
}
