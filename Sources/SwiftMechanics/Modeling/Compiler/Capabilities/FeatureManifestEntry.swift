public struct FeatureManifestEntry: Equatable, Sendable {
    public let requirement: FeatureRequirement
    public let owner: String
    public let evidenceRevision: String
    public let qualification: FeatureQualification

    public init(requirement: FeatureRequirement, owner: String, evidenceRevision: String, qualification: FeatureQualification) {
        self.requirement = requirement; self.owner = owner; self.evidenceRevision = evidenceRevision; self.qualification = qualification
    }
}
