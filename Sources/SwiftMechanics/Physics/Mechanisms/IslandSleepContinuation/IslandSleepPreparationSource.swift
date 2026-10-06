@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class IslandSleepPreparationSource: Sendable {
    let source: RuntimeAcceptedState
    let history: IslandSleepHistory

    init(source: RuntimeAcceptedState, history: IslandSleepHistory) {
        self.source = source
        self.history = history
    }
}
