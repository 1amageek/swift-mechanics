public struct XMLPolicy: Sendable {
    public let maximumInputBytes: Int
    public let maximumOutputBytes: Int
    public let maximumNodes: Int
    public let maximumAttributes: Int
    public let maximumAttributesPerElement: Int
    public let maximumDepth: Int
    public let maximumDecodedBytes: Int
    public let maximumStorageBytes: Int
    public let maximumOperations: Int
    public init(maximumInputBytes: Int, maximumOutputBytes: Int, maximumNodes: Int,
                maximumAttributes: Int, maximumAttributesPerElement: Int, maximumDepth: Int,
                maximumDecodedBytes: Int, maximumStorageBytes: Int, maximumOperations: Int) throws(XMLFailure) {
        guard maximumInputBytes >= 0, maximumOutputBytes >= 0, maximumNodes >= 0,
              maximumAttributes >= 0, maximumAttributesPerElement >= 0, maximumDepth >= 0,
              maximumDecodedBytes >= 0, maximumStorageBytes >= 0, maximumOperations >= 0 else {
            throw XMLFailure(.invalidPolicy, at: XMLLocation())
        }
        self.maximumInputBytes = maximumInputBytes; self.maximumOutputBytes = maximumOutputBytes
        self.maximumNodes = maximumNodes; self.maximumAttributes = maximumAttributes
        self.maximumAttributesPerElement = maximumAttributesPerElement; self.maximumDepth = maximumDepth
        self.maximumDecodedBytes = maximumDecodedBytes; self.maximumStorageBytes = maximumStorageBytes
        self.maximumOperations = maximumOperations
    }
}
