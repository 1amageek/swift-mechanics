/// Exclusive local ledger. Retain this same value throughout one bounded run, including rejected trials.
public struct WheeledAssemblyWork: Sendable {
    public let maximumSteps, maximumModelCalls: Int
    public internal(set) var steps = 0, modelCalls = 0
    public internal(set) var terminal = false
    public internal(set) var numerical: NumericalWork
    public internal(set) var loads: LoadWork
    public internal(set) var actuation: ActuationWork
    public init(maximumSteps: Int, maximumModelCalls: Int, numerical: NumericalWork, loads: LoadWork, actuation: ActuationWork) throws(WheeledAssemblyFailure) {
        guard maximumSteps >= 0, maximumModelCalls >= 0 else { throw .refusal(.invalidInput) }
        self.maximumSteps=maximumSteps; self.maximumModelCalls=maximumModelCalls
        self.numerical=numerical; self.loads=loads; self.actuation=actuation
    }
    internal mutating func check() throws(WheeledAssemblyFailure) {
        guard !terminal else { throw .refusal(.terminalSupplierFailure) }
        guard !Task.isCancelled, !loads.budget.isCancelled(), !actuation.budget.isCancelled() else { throw .refusal(.cancelled) }
    }
    internal mutating func modelCall() throws(WheeledAssemblyFailure) {
        try check(); guard modelCalls < maximumModelCalls else { throw .refusal(.workExhausted) }; modelCalls += 1
    }
    internal mutating func admitStep() throws(WheeledAssemblyFailure) {
        try check(); guard steps < maximumSteps else { throw .refusal(.workExhausted) }; steps += 1
    }
}
