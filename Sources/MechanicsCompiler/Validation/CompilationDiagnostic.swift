import MechanicsModel

public struct CompilationDiagnostic: Equatable, Sendable {
    public let code: CompilationCode
    public let stage: CompilationStage
    public let records: [EntityID]
    public let message: String

    public init(code: CompilationCode, stage: CompilationStage, records: [EntityID], message: String) {
        self.code = code; self.stage = stage; self.records = records; self.message = message
    }
}
