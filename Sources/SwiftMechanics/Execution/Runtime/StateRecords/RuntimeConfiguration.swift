public struct RuntimeConfiguration: Equatable, Sendable {
    public let continuation: RuntimeContinuationIdentity
    public let requiredContributors: [RuntimeContributorSchema]
    public let capacity: RuntimeCapacity
    public let determinism: RuntimeDeterminismTier
    public let workload: String
    public init(continuation: RuntimeContinuationIdentity, requiredContributors: [RuntimeContributorSchema],
                capacity: RuntimeCapacity, determinism: RuntimeDeterminismTier, workload: String) throws(RuntimeFailure) {
        guard !workload.isEmpty, requiredContributors.count <= capacity.maximumContributors else { throw RuntimeFailure(.capacityExceeded, message: "Workload identity/schema count violates capacity.") }
        var seen: Set<String> = [], bytes = 0
        for text in [workload, continuation.build, continuation.backend, continuation.precision] { bytes = try RuntimeCounts.sum(bytes, text.utf8.count) }
        for schema in requiredContributors {
            guard seen.insert(schema.id).inserted else { throw RuntimeFailure(.duplicateContributor, contributor: schema.id, message: "Required schema identity is duplicated.") }
            bytes = try RuntimeCounts.sum(bytes, schema.id.utf8.count)
            guard schema.maximumBytes <= capacity.maximumContributorBytes else { throw RuntimeFailure(.capacityExceeded, contributor: schema.id, message: "Schema byte bound exceeds runtime capacity.") }
        }
        guard bytes <= capacity.maximumMetadataBytes else { throw RuntimeFailure(.capacityExceeded, message: "Configuration metadata exceeds byte capacity.") }
        self.continuation = continuation; self.requiredContributors = requiredContributors.sorted { $0.id < $1.id }
        self.capacity = capacity; self.determinism = determinism; self.workload = workload
    }
}
