public struct LoadBudget: Sendable {
    public let maximumWork: Int
    public let maximumScalars: Int
    public let isCancelled: @Sendable () -> Bool
    public init(maximumWork: Int, maximumScalars: Int,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(LoadError) {
        guard maximumWork >= 0, maximumScalars >= 0 else { throw .invalidInput }
        self.maximumWork = maximumWork; self.maximumScalars = maximumScalars
        self.isCancelled = isCancelled
    }
}
