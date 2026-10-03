import MechanicsCore

public struct ExtensionParameter: Equatable, Sendable {
    public let name: String
    public let value: Double
    public let dimension: PhysicalDimension

    public init(name: String, value: Double, dimension: PhysicalDimension) throws(CompilationFailure) {
        guard !name.isEmpty, value.isFinite else { throw .one(.invalidInput, .extensionValidation, message: "Parameters require a nonempty name and finite SI value.") }
        self.name = name; self.value = value; self.dimension = dimension
    }
}
