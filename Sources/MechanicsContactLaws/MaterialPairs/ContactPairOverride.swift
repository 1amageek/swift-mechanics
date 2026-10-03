import MechanicsModel
public struct ContactPairOverride: Sendable {
    public let first: ModelReference
    public let second: ModelReference
    public let revision: UInt64
    public let parameters: ContactResolvedParameters
    public init(first: ModelReference, second: ModelReference, revision: UInt64, parameters: ContactResolvedParameters) throws(ContactLawError) {
        guard first.id.kind == .material, second.id.kind == .material else { throw .invalidIdentity }
        self.first=first; self.second=second; self.revision=revision; self.parameters=parameters
    }
}
