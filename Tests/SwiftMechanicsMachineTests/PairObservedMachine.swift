import SwiftMechanics

@available(macOS 15.0, *)
struct PairObservedMachine: Machine {
    let counter: MachineCounter
    let failure: MachineDefinitionFailure?

    var body: Never { fatalError("Observed lowering must not evaluate body.") }

    func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        counter.content()
        if let failure { throw failure }
    }
}
