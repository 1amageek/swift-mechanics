@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct RuntimeStepControl: Sendable {
    private let source: RuntimeCancellationSource
    internal init(source: RuntimeCancellationSource) { self.source = source }
    public var admittedWorkUnits: Int { source.admittedWorkUnits }
    public func beginWorkBlock(units: Int) throws(RuntimeFailure) { try source.admitWork(units) }
    internal func isBound(to expected: RuntimeCancellationSource) -> Bool { source === expected }
}
