public struct StationaryIslandPolicy: Sendable {
    public let maximumIslands: Int
    public let maximumSignatureBytes: Int
    public let maximumIdentifierBytes: Int
    public let maximumCompilationCalls: Int
    public let mechanics: MechanismSolvePolicy
    public let admission: DynamicsAdmission
    public init(maximumIslands: Int, maximumSignatureBytes: Int, maximumIdentifierBytes: Int,
                maximumCompilationCalls: Int, mechanics: MechanismSolvePolicy, admission: DynamicsAdmission) throws(StationaryIslandFailureReason) {
        guard maximumIslands > 0, maximumSignatureBytes > 0, maximumIdentifierBytes > 0,
              maximumCompilationCalls > 0 else { throw .invalidInput }
        self.maximumIslands=maximumIslands; self.maximumSignatureBytes=maximumSignatureBytes
        self.maximumIdentifierBytes=maximumIdentifierBytes; self.maximumCompilationCalls=maximumCompilationCalls
        self.mechanics=mechanics; self.admission=admission
    }
}
