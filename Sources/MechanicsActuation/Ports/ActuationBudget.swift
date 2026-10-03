public struct ActuationBudget: Sendable {
    public let maximumWork:Int, maximumScalars:Int, maximumBytes:Int, maximumBindings:Int, maximumMetadataBytes:Int
    public let isCancelled:@Sendable () -> Bool
    public init(maximumWork:Int,maximumScalars:Int,maximumBytes:Int,maximumBindings:Int,maximumMetadataBytes:Int,
                isCancelled:@escaping @Sendable () -> Bool = { false }) throws(ActuationError) {
        guard maximumWork >= 0,maximumScalars >= 0,maximumBytes >= 0,maximumBindings >= 0,maximumMetadataBytes >= 0 else { throw .invalidInput }
        self.maximumWork=maximumWork;self.maximumScalars=maximumScalars;self.maximumBytes=maximumBytes;self.maximumBindings=maximumBindings;self.maximumMetadataBytes=maximumMetadataBytes;self.isCancelled=isCancelled
    }
}
