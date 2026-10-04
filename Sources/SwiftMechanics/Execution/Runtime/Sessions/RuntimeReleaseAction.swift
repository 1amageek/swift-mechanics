@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct RuntimeReleaseAction: Sendable {
    let status: RuntimeShutdownStatus
    let release: Bool
    let source: RuntimeCancellationSource?
    let retiredWorkspace: RuntimeTrial?
}
