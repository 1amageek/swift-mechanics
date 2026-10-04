public struct GeometricConstraintCapacity: Sendable {
    public let maximumBodies: Int
    public let maximumPositions: Int
    public let maximumVelocities: Int
    public let maximumRows: Int
    public let maximumMetadataBytes: Int
    public init(maximumBodies:Int,maximumPositions:Int,maximumVelocities:Int,maximumRows:Int,maximumMetadataBytes:Int) throws(GeometricConstraintError) {
        guard maximumBodies > 0,maximumPositions > 0,maximumVelocities > 0,maximumRows > 0,maximumMetadataBytes > 0 else { throw .invalidInput }
        self.maximumBodies=maximumBodies;self.maximumPositions=maximumPositions;self.maximumVelocities=maximumVelocities
        self.maximumRows=maximumRows;self.maximumMetadataBytes=maximumMetadataBytes
    }
}
