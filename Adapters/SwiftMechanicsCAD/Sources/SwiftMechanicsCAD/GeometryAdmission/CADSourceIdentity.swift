import CADCore
import CADIR

public struct CADSourceIdentity: Hashable, Sendable {
    public static let supportedProviderPin = "295a724cdf0219c904007c2735f2b99ef08200ca"
    public let providerPin: String
    public let documentID: DocumentID
    public let designRevision: DocumentRevision
    public let parameterRevision: DocumentRevision
    public let fingerprint: CADDocumentSourceFingerprint
    public let units: UnitSystem
    public let tolerance: ModelingTolerance

    /// An expectation is metadata, not an admitted geometry owner.
    public init(providerPin: String, documentID: DocumentID, designRevision: DocumentRevision,
                parameterRevision: DocumentRevision, fingerprint: CADDocumentSourceFingerprint,
                units: UnitSystem, tolerance: ModelingTolerance) {
        self.providerPin = providerPin
        self.documentID = documentID
        self.designRevision = designRevision
        self.parameterRevision = parameterRevision
        self.fingerprint = fingerprint
        self.units = units
        self.tolerance = tolerance
    }
}
