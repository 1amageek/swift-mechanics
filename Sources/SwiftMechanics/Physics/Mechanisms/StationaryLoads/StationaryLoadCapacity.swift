public struct StationaryLoadCapacity: Sendable {
    public let maximumPrograms:Int
    public let maximumTermsPerProgram:Int
    public let maximumCoordinates:Int
    public let maximumMetadataBytes:Int
    public init(maximumPrograms:Int,maximumTermsPerProgram:Int,maximumCoordinates:Int,maximumMetadataBytes:Int) throws(StationaryLoadError) {
        guard maximumPrograms > 0,maximumTermsPerProgram >= 0,maximumCoordinates > 0,maximumMetadataBytes > 0 else { throw .invalidInput }
        self.maximumPrograms=maximumPrograms;self.maximumTermsPerProgram=maximumTermsPerProgram;self.maximumCoordinates=maximumCoordinates;self.maximumMetadataBytes=maximumMetadataBytes
    }
}
