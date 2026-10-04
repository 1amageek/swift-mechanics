public struct ConstraintEvaluationPolicy: Sendable {
    public let maximumCoordinates: Int
    public let maximumRows: Int
    public let expectedLayoutRevision: UInt64
    public let isCancelled: @Sendable () -> Bool
    public init(maximumCoordinates: Int, maximumRows: Int, expectedLayoutRevision: UInt64, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(ConstraintError) {
        guard maximumCoordinates > 0, maximumRows > 0 else { throw .invalidInput }
        self.maximumCoordinates=maximumCoordinates; self.maximumRows=maximumRows
        self.expectedLayoutRevision=expectedLayoutRevision; self.isCancelled=isCancelled
    }
}
