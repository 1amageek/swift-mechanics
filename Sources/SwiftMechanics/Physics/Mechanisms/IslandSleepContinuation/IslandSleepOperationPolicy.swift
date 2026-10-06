public struct IslandSleepOperationPolicy: Sendable {
    public let maximumSupplierInvocations: Int
    public let maximumQueries: Int
    public let maximumQuerySteps: Int
    public let maximumRecordBytes: Int
    public init(maximumSupplierInvocations: Int, maximumQueries: Int, maximumQuerySteps: Int, maximumRecordBytes: Int) throws(RuntimeFailure) {
        guard maximumSupplierInvocations > 0, maximumQueries >= 0, maximumQuerySteps > 0, maximumRecordBytes > 0 else { throw RuntimeFailure(.invalidInput,message:"Invalid island operation capacities.") }
        self.maximumSupplierInvocations=maximumSupplierInvocations; self.maximumQueries=maximumQueries
        self.maximumQuerySteps=maximumQuerySteps; self.maximumRecordBytes=maximumRecordBytes
    }
}
