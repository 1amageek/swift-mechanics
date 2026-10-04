public struct ObservationPolicy: Sendable {
    public let maximumBodies: Int
    public let maximumCoordinates: Int
    public let maximumReactionRows: Int
    /// Maximum UTF8 bytes in one admitted identity-record or mounting group; aggregate work is separately bounded.
    public let maximumMetadataBytes: Int
    public let isCancelled: @Sendable () -> Bool
    public init(maximumBodies: Int, maximumCoordinates: Int, maximumReactionRows: Int, maximumMetadataBytes: Int,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(ObservationError) {
        guard maximumBodies > 0, maximumCoordinates >= 0, maximumReactionRows >= 0, maximumMetadataBytes >= 0 else { throw .invalidInput }
        self.maximumBodies=maximumBodies; self.maximumCoordinates=maximumCoordinates;self.maximumReactionRows=maximumReactionRows
        self.maximumMetadataBytes=maximumMetadataBytes; self.isCancelled=isCancelled
    }
}
