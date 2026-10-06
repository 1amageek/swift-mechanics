public struct AssetResolutionFailure: Error, Sendable {
    public enum Reason: Sendable {
        case invalidPolicy, invalidInput, invalidReference, missingDeclaration, unsupportedFormat
        case duplicateAddress, duplicateKey, duplicateDependency, duplicateRoot, cycle
        case metadataMismatch, bytesMismatch, dependencyMismatch
        case providerContract(cause: AssetProviderFailure?, previous: AssetProviderWork, observed: AssetProviderWork)
        case cancelled, arithmeticOverflow, limit(AssetResource, Int), provider(AssetProviderFailure)
    }
    public let reason: Reason
    public let address: AssetAddress?
    public init(_ reason: Reason, address: AssetAddress? = nil) { self.reason = reason; self.address = address }
}
