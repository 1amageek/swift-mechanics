/// An ordered binary composition with a stable accumulated builder type.
public struct ErasedPairMachine: Machine {
    private let storage: any PairMachineStorage

    public init<First: Machine, Second: Machine>(_ first: First, _ second: Second) {
        storage = ConcretePairMachineStorage(first, second)
    }

    public var body: Never { fatalError("Erased pair lowering must not evaluate body.") }

    // FIXME(INCOMPLETE_IMPLEMENTATION): This causal builder representation is implemented
    // but not yet behaviorally qualified. MachineBuilder selects it for accumulated pairs;
    // exact ordering/budget/failure regressions and unchanged Structural Native/WASM/Embedded
    // physical cases must pass before the original bounded-stack counterexample is closed.
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        try storage.lower(into: &context)
    }
}

private protocol PairMachineStorage: Sendable {
    func lower(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure)
}

private final class ConcretePairMachineStorage<First: Machine, Second: Machine>: PairMachineStorage {
    let first: First
    let second: Second

    init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }

    func lower(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        // Dispatch replaces one TupleMachine node; an AnyMachine wrapper would add a visit.
        try context.lower(first)
        try context.lower(second)
    }
}
