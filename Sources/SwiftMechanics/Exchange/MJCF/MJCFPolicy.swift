public struct MJCFPolicy: Sendable {
    public let maximumBodies: Int
    public let maximumFeatures: Int
    public let maximumDefaults: Int
    public let maximumAttributes: Int
    public let maximumIdentifierBytes: Int
    public let maximumStorageBytes: Int
    public let maximumOperations: Int
    public let allowedLosses: [MJCFLossCategory]
    public let isCancelled: @Sendable () -> Bool
    public init(maximumBodies: Int, maximumFeatures: Int, maximumDefaults: Int, maximumAttributes: Int,
                maximumIdentifierBytes: Int, maximumStorageBytes: Int, maximumOperations: Int,
                allowedLosses: [MJCFLossCategory], isCancelled: @escaping @Sendable () -> Bool = { false }) throws(MJCFError) {
        guard maximumBodies > 0, maximumFeatures >= 0, maximumDefaults >= 0, maximumAttributes >= 0,
              maximumIdentifierBytes >= 0, maximumStorageBytes >= 0, maximumOperations >= 0, allowedLosses.count <= 6 else { throw .invalidPolicy }
        for i in allowedLosses.indices { for j in 0..<i { guard allowedLosses[i] != allowedLosses[j] else { throw .invalidPolicy } } }
        self.maximumBodies = maximumBodies; self.maximumFeatures = maximumFeatures; self.maximumDefaults = maximumDefaults
        self.maximumAttributes = maximumAttributes; self.maximumIdentifierBytes = maximumIdentifierBytes
        self.maximumStorageBytes = maximumStorageBytes; self.maximumOperations = maximumOperations
        self.allowedLosses = allowedLosses; self.isCancelled = isCancelled
    }
}
