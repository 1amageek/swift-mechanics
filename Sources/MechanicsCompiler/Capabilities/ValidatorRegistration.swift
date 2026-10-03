public struct ValidatorRegistration: Equatable, Sendable {
    public let schema: String
    public let feature: String
    public let owner: String
    public let evidenceRevision: String
    public let operation: FeatureOperation

    public init(schema: String, feature: String, owner: String, evidenceRevision: String, operation: FeatureOperation) throws(CompilationFailure) {
        guard !schema.isEmpty, !feature.isEmpty, !owner.isEmpty, !evidenceRevision.isEmpty else {
            throw .one(.invalidInput, .capabilities, message: "Validator registration requires schema, feature, owner and evidence revision.")
        }
        self.schema = schema; self.feature = feature; self.owner = owner; self.evidenceRevision = evidenceRevision; self.operation = operation
    }
}
