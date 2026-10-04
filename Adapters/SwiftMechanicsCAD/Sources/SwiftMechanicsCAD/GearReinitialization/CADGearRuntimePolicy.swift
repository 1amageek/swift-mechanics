import SwiftMechanics

public struct CADGearRuntimePolicy: Sendable {
    public let capacity: RuntimeCapacity
    public let continuation: RuntimeContinuationIdentity
    public let determinism: RuntimeDeterminismTier
    public let workload: String
    public let seed: UInt64
    public let maximumRecipeBytes: Int
    public let maximumMetadataBytes: Int
    public init(capacity: RuntimeCapacity, continuation: RuntimeContinuationIdentity,
                determinism: RuntimeDeterminismTier, workload: String, seed: UInt64,
                maximumRecipeBytes: Int, maximumMetadataBytes: Int) throws(CADGearReinitializationError) {
        guard maximumRecipeBytes > 0, maximumMetadataBytes > 0,
              maximumRecipeBytes <= capacity.maximumContributorBytes,
              maximumMetadataBytes <= capacity.maximumMetadataBytes,
              !workload.isEmpty, workload.utf8.count <= maximumMetadataBytes else { throw .capacityExceeded }
        self.capacity = capacity; self.continuation = continuation; self.determinism = determinism
        self.workload = workload; self.seed = seed; self.maximumRecipeBytes = maximumRecipeBytes
        self.maximumMetadataBytes = maximumMetadataBytes
    }
}
