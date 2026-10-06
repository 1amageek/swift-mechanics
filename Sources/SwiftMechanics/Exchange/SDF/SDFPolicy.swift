public struct SDFPolicy: Sendable {
    public let xml: XMLPolicy
    public let semanticBudget: NumericalBudget
    public let maximumNamedRecords: Int
    public let maximumTokenBytes: Int
    public let maximumAssetBytes: Int
    public init(xml: XMLPolicy, semanticBudget: NumericalBudget, maximumNamedRecords: Int,
                maximumTokenBytes: Int, maximumAssetBytes: Int) throws(SDFError) {
        guard maximumNamedRecords > 0, maximumTokenBytes > 0, maximumAssetBytes >= 0 else { throw .invalidPolicy }
        self.xml = xml; self.semanticBudget = semanticBudget; self.maximumNamedRecords = maximumNamedRecords
        self.maximumTokenBytes = maximumTokenBytes; self.maximumAssetBytes = maximumAssetBytes
    }
}
