public struct ContactRangeObservationPolicy: Sendable {
    public let observation: ObservationPolicy
    public let query: CollisionQueryPolicy
    public let contact: ContactAcceptancePolicy
    public let maximumColliders: Int
    public let maximumHits: Int
    public let maximumTactileBindings: Int
    public let maximumTriggerRecords: Int
    public let maximumMetadataBytes: Int
    public init(observation: ObservationPolicy, query: CollisionQueryPolicy, contact: ContactAcceptancePolicy,
                maximumColliders: Int, maximumHits: Int, maximumTactileBindings: Int,
                maximumTriggerRecords: Int, maximumMetadataBytes: Int) throws(ContactRangeObservationError) {
        guard maximumColliders >= 0, maximumHits >= 0, maximumTactileBindings >= 0,
              maximumTriggerRecords >= 0, maximumMetadataBytes >= 0 else { throw .invalidInput }
        self.observation=observation;self.query=query;self.contact=contact
        self.maximumColliders=maximumColliders;self.maximumHits=maximumHits
        self.maximumTactileBindings=maximumTactileBindings;self.maximumTriggerRecords=maximumTriggerRecords
        self.maximumMetadataBytes=maximumMetadataBytes
    }
}
