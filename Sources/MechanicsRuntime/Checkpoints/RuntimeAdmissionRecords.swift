/// Immutable metadata retained by one checkpoint admission operation.
internal final class RuntimeAdmissionRecords: Sendable {
    let registry: [String: RuntimeContributorSchema]
    let records: [String: RuntimeContributorState]
    init(registry: [String: RuntimeContributorSchema], records: [String: RuntimeContributorState]) {
        self.registry = registry
        self.records = records
    }
}
