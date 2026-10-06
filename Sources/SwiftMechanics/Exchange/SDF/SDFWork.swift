public struct SDFWork: Sendable {
    public let policy: SDFPolicy
    public private(set) var xml: XMLWork
    public private(set) var semantics: NumericalWork
    public init(policy: SDFPolicy) {
        self.policy = policy; self.xml = XMLWork(policy: policy.xml)
        self.semantics = NumericalWork(budget: policy.semanticBudget)
    }
    internal mutating func charge(_ amount: Int) throws(SDFError) {
        guard !Task.isCancelled else { throw .numerical(.cancelled) }
        do { try semantics.chargeOperations(amount) } catch { throw .numerical(error) }
    }
    internal mutating func reserve(_ amount: Int) throws(SDFError) {
        try charge(0)
        do { try semantics.requireStorage(amount) } catch { throw .numerical(error) }
    }
    internal mutating func row() throws(SDFError) {
        do { try semantics.advanceIteration() } catch { throw .numerical(error) }
    }
    internal mutating func inspect(_ value: String) throws(SDFError) {
        for _ in value.utf8 { try charge(2) }
    }
    internal mutating func comparisons(_ count: Int) throws(SDFError) {
        let amount: Int
        do throws(NumericalError) {
            amount = try NumericalWork.product(count, NumericalWork.product(policy.maximumTokenBytes, 4))
        } catch { throw .numerical(error) }
        try charge(amount)
    }
    internal mutating func decodeXML(_ bytes: [UInt8]) throws(SDFError) -> XMLDocument {
        do { return try BoundedXMLCodec().decode(bytes: bytes, work: &xml) }
        catch { throw .xml(error) }
    }
    internal mutating func encodeXML(_ document: XMLDocument) throws(SDFError) -> [UInt8] {
        do { return try BoundedXMLCodec().encode(document: document, work: &xml) }
        catch { throw .xml(error) }
    }
}
