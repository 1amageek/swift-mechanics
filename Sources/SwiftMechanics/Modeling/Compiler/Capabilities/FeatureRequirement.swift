
public struct FeatureRequirement: Equatable, Sendable {
    public let feature: String
    public let operation: FeatureOperation
    public let domain: MechanicalDomain
    public let precision: NumericalPrecision
    public let backend: NumericalBackend
    public let target: CompilerTarget

    public init(feature: String, operation: FeatureOperation, domain: MechanicalDomain,
                precision: NumericalPrecision, backend: NumericalBackend, target: CompilerTarget) throws(CompilationFailure) {
        guard !feature.isEmpty else { throw .one(.invalidInput, .capabilities, message: "Feature identity must be nonempty.") }
        self.feature = feature; self.operation = operation; self.domain = domain
        self.precision = precision; self.backend = backend; self.target = target
    }
}
