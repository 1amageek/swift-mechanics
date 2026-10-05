public struct URDFPolicy: Equatable, Sendable {
    public let maximumLinks: Int
    public let maximumJoints: Int
    public let maximumGeometryRecords: Int
    public let maximumAssets: Int
    public let maximumLosses: Int
    public let maximumIdentifierBytes: Int
    public let maximumReferenceBytes: Int
    public let maximumOperations: Int
    public let maximumStorageBytes: Int

    public init(maximumLinks: Int, maximumJoints: Int, maximumGeometryRecords: Int, maximumAssets: Int,
                maximumLosses: Int, maximumIdentifierBytes: Int, maximumReferenceBytes: Int,
                maximumOperations: Int, maximumStorageBytes: Int) throws(URDFFailure) {
        guard maximumLinks >= 0, maximumJoints >= 0, maximumGeometryRecords >= 0, maximumAssets >= 0,
              maximumLosses >= 0, maximumIdentifierBytes >= 0, maximumReferenceBytes >= 0,
              maximumOperations >= 0, maximumStorageBytes >= 0 else { throw URDFFailure(.invalidPolicy) }
        self.maximumLinks = maximumLinks; self.maximumJoints = maximumJoints
        self.maximumGeometryRecords = maximumGeometryRecords; self.maximumAssets = maximumAssets
        self.maximumLosses = maximumLosses; self.maximumIdentifierBytes = maximumIdentifierBytes
        self.maximumReferenceBytes = maximumReferenceBytes; self.maximumOperations = maximumOperations
        self.maximumStorageBytes = maximumStorageBytes
    }
}
