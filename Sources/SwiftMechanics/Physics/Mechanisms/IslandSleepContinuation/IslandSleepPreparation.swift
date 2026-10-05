@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class IslandSleepPreparation: Sendable {
    let source:RuntimeAcceptedState
    let history:IslandSleepHistory
    let proofs:[StationaryIslandRestCertificate?]
    init(source:RuntimeAcceptedState,history:IslandSleepHistory,proofs:[StationaryIslandRestCertificate?]) { self.source=source;self.history=history;self.proofs=proofs }
}
