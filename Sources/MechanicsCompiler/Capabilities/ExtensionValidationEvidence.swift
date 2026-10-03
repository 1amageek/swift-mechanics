import MechanicsNumerics

public struct ExtensionValidationEvidence: Equatable, Sendable {
    public let feature: String
    public let dependencies: [ParameterReference]
    public let work: NumericalWork

    public init(feature: String, dependencies: [ParameterReference], work: NumericalWork) {
        self.feature = feature; self.dependencies = dependencies; self.work = work
    }
}
