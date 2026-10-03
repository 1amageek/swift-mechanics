import MechanicsModel

public struct CompilationFailure: Error, Equatable, Sendable {
    public let diagnostics: [CompilationDiagnostic]

    public init(diagnostic: CompilationDiagnostic) { diagnostics = [diagnostic] }

    public init(diagnostics: [CompilationDiagnostic]) throws(CompilationFailure) {
        guard !diagnostics.isEmpty else {
            throw Self.one(.invalidInput, .input, message: "A failure requires at least one diagnostic.")
        }
        self.diagnostics = diagnostics
    }

    public static func one(_ code: CompilationCode, _ stage: CompilationStage,
                           records: [EntityID] = [], message: String) -> CompilationFailure {
        CompilationFailure(diagnostic: CompilationDiagnostic(code: code, stage: stage, records: records, message: message))
    }
}
