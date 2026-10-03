/// Immutable accepted-state snapshot. Evaluators never expose an accepted-state mutation handle.
public struct CustomLoadState: Equatable, Sendable {
    public let revision: Int
    public let values: [Double]
    public init(revision: Int, values: [Double]) throws(LoadError) {
        guard revision >= 0, values.allSatisfy({ $0.isFinite }) else { throw .invalidInput }
        self.revision = revision; self.values = values
    }
}
