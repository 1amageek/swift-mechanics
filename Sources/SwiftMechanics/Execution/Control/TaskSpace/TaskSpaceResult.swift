/// Tentative command; actual actuator mapping and Runtime publication belong to consumers.
public final class TaskSpaceResult: Sendable {
    public let request: TaskSpaceRequest
    public let generalizedEffort: [Double]
    public let physicalResponse: PhysicalDynamicsSolution
    public let diagnostics: TaskSpaceDiagnostics
    internal init(request: TaskSpaceRequest, generalizedEffort: [Double], physicalResponse: PhysicalDynamicsSolution,
                  diagnostics: TaskSpaceDiagnostics) {
        self.request = request; self.generalizedEffort = generalizedEffort
        self.physicalResponse = physicalResponse; self.diagnostics = diagnostics
    }
}
