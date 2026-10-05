@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class IslandSleepPreparation: Sendable {
    private let context:IslandSleepPreparationSource
    var source:RuntimeAcceptedState { context.source }
    var history:IslandSleepHistory { context.history }
    let proofs:[StationaryIslandRestCertificate?]
    init(context:IslandSleepPreparationSource,proofs:[StationaryIslandRestCertificate?]) { self.context=context;self.proofs=proofs }
}
