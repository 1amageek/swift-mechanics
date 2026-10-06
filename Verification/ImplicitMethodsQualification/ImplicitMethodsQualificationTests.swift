import SwiftMechanics
import Testing
#if canImport(ImplicitMethodsQualificationSupport)
import ImplicitMethodsQualificationSupport
#endif

@Suite("Original implicit mechanical methods")
struct ImplicitMethodsQualificationTests {
    @Test(.timeLimit(.minutes(1))) func eulerPhysicalEndpointAndEnergy() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw ImplicitMethodsQualificationError.unsupportedPlatform }
        try ImplicitMethodsQualificationCases.eulerPhysicalEndpointAndEnergy() }
    @Test(.timeLimit(.minutes(1))) func eulerOrderAndRepeat() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw ImplicitMethodsQualificationError.unsupportedPlatform }
        try ImplicitMethodsQualificationCases.eulerOrderAndRepeat() }
    @Test(.timeLimit(.minutes(1))) func generalizedAlphaEndpoints() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw ImplicitMethodsQualificationError.unsupportedPlatform }
        try ImplicitMethodsQualificationCases.generalizedAlphaEndpoints() }
    @Test(.timeLimit(.minutes(1))) func hhtOriginalEndpointsAndEnergy() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw ImplicitMethodsQualificationError.unsupportedPlatform }
        try ImplicitMethodsQualificationCases.hhtOriginalEndpointsAndEnergy() }
    @Test(.timeLimit(.minutes(1))) func providerRefusalAndRollback() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw ImplicitMethodsQualificationError.unsupportedPlatform }
        try ImplicitMethodsQualificationCases.providerRefusalAndRollback() }
    @Test(.timeLimit(.minutes(1))) func domainAndExclusiveOwner() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw ImplicitMethodsQualificationError.unsupportedPlatform }
        try ImplicitMethodsQualificationCases.domainAndExclusiveOwner() }
    @Test(.timeLimit(.minutes(1))) func budgetsAndCallbackCancellation() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw ImplicitMethodsQualificationError.unsupportedPlatform }
        try ImplicitMethodsQualificationCases.budgetsAndCallbackCancellation() }
    @Test(.timeLimit(.minutes(1))) func nativeTaskCancellation() async throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw ImplicitMethodsQualificationError.unsupportedPlatform }
        let physics = try ImplicitQualificationPhysics(), model = try ImplicitMethodsQualificationFixtures.model(physics)
        let session = try ImplicitMethodsQualificationFixtures.session(model, physics: physics)
        defer { _ = session.shutdown() }
        let equation = try ImplicitQualificationODE(model: model, physics: physics), policy = try ImplicitMethodsQualificationFixtures.eulerPolicy()
        let initial = session.snapshot()
        let task = Task.detached { () -> Result<Void, ImplicitMethodsQualificationError> in
            while !Task.isCancelled { await Task.yield() }
            do throws(ImplicitMethodsQualificationError) {
                try ImplicitMethodsQualificationCases.eulerFailure(session, model: model, equation: equation, policy: policy) {
                    if case .numerical(.cancelled) = $0 { return true }; return false
                }
                try ImplicitMethodsQualificationFixtures.require(session.snapshot() == initial && session.profile().attemptedTransactions == 0,
                    "Task cancellation completes before checkout without state publication.")
                return .success(())
            } catch { return .failure(error) }
        }
        task.cancel()
        try await task.value.get()
    }
}
