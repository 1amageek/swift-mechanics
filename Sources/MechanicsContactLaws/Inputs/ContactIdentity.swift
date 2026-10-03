import MechanicsModel
public struct ContactIdentity: Equatable, Sendable {
    public let key: String
    public let firstBody: ModelReference
    public let secondBody: ModelReference
    public let frame: ModelReference
    public let firstGeometryRevision: UInt64
    public let secondGeometryRevision: UInt64
    public let tangentLayoutRevision: UInt64
    private let materialSites: ContactMaterialSitePair?
    public var firstMaterialSite: ContactMaterialSite? { materialSites?.first }
    public var secondMaterialSite: ContactMaterialSite? { materialSites?.second }
    public init(key: String, firstBody: ModelReference, secondBody: ModelReference, frame: ModelReference,
                firstGeometryRevision: UInt64, secondGeometryRevision: UInt64, tangentLayoutRevision: UInt64,
                firstMaterialSite: ContactMaterialSite? = nil, secondMaterialSite: ContactMaterialSite? = nil) throws(ContactLawError) {
        guard !key.isEmpty, firstBody.id.kind == .body, secondBody.id.kind == .body,
              frame.id.kind == .frame else { throw .invalidIdentity }
        guard (firstMaterialSite == nil) == (secondMaterialSite == nil) else { throw .invalidIdentity }
        if firstBody.id == secondBody.id {
            guard firstBody == secondBody,
                  let firstMaterialSite, let secondMaterialSite,
                  firstMaterialSite.key != secondMaterialSite.key else { throw .invalidIdentity }
        }
        self.key=key; self.firstBody=firstBody; self.secondBody=secondBody; self.frame=frame
        self.firstGeometryRevision=firstGeometryRevision; self.secondGeometryRevision=secondGeometryRevision
        self.tangentLayoutRevision=tangentLayoutRevision
        if let firstMaterialSite, let secondMaterialSite {
            materialSites=ContactMaterialSitePair(first:firstMaterialSite,second:secondMaterialSite)
        } else { materialSites=nil }
    }

    internal var materialSiteScalarStorage: Int { materialSites == nil ? 0 : 32 }
}
