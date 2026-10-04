
public struct MechanicalExtensionRecord: Equatable, Sendable {
    public let id: EntityID
    public let schema: String
    public let references: [EntityID]
    public let parameters: [ExtensionParameter]

    public init(id: EntityID, schema: String, references: [EntityID], parameters: [ExtensionParameter]) throws(CompilationFailure) {
        guard id.kind != .body, id.kind != .frame, !schema.isEmpty else {
            throw .one(.invalidInput, .extensionValidation, records: [id], message: "Extensions require a distinct non-body/frame record and nonempty schema.")
        }
        var names: Set<String> = []
        for parameter in parameters {
            guard names.insert(parameter.name).inserted else { throw .one(.invalidInput, .extensionValidation, records: [id], message: "Parameter names must be unique.") }
        }
        self.id = id; self.schema = schema; self.references = references; self.parameters = parameters
    }
}
