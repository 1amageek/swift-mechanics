import SwiftMechanics
import Testing

struct MachinePairTests {
    @Test func orderedRecordsHaveOriginalBinaryPairBudgets() throws {
        let a = MachineBody(try MachineFixtures.body("a"))
        let b = MachineBody(try MachineFixtures.body("b"))
        let c = MachineBody(try MachineFixtures.body("c"))
        let original = try MachineFixtures.definition { TupleMachine(TupleMachine(a, b), c) }
        let current = try MachineFixtures.definition { a; b; c }
        let exact = try MachineFixtures.policy(nodes: 5, depth: 3)
        #expect(try original.makeDescriptor(policy: exact).bodies.map { $0.id.key } == ["a", "b", "c"])
        #expect(try current.makeDescriptor(policy: exact).bodies.map { $0.id.key } == ["a", "b", "c"])

        for erased in [false, true] {
            do {
                if erased { _ = try current.makeDescriptor(policy: MachineFixtures.policy(nodes: 4, depth: 3)) }
                else { _ = try original.makeDescriptor(policy: MachineFixtures.policy(nodes: 4, depth: 3)) }
                Issue.record("Five binary-pair/leaf visits must not fit four nodes.")
            } catch MachineDefinitionFailure.capacityExceeded {}
            do {
                if erased { _ = try current.makeDescriptor(policy: MachineFixtures.policy(nodes: 5, depth: 2)) }
                else { _ = try original.makeDescriptor(policy: MachineFixtures.policy(nodes: 5, depth: 2)) }
                Issue.record("Nested pair leaves must require depth three.")
            } catch MachineDefinitionFailure.depthExceeded {}
        }
    }

    @available(macOS 15.0, *)
    @Test func directPairCutoffsAndFailuresPreserveInvocationPrefix() throws {
        let cases: [(nodes: Int, depth: Int, firstFailure: MachineDefinitionFailure?,
                     expectedFailure: MachineDefinitionFailure?, firstCalls: Int, secondCalls: Int)] = [
            (3, 2, nil, nil, 1, 1),
            (2, 2, nil, .capacityExceeded, 1, 0),
            (3, 1, nil, .depthExceeded, 0, 0),
            (3, 2, .invalidNamespace, .invalidNamespace, 1, 0)
        ]
        for selected in cases {
            for erased in [false, true] {
                let first = MachineCounter(), second = MachineCounter()
                let a = PairObservedMachine(counter: first, failure: selected.firstFailure)
                let b = PairObservedMachine(counter: second, failure: nil)
                var context = MachineDefinitionContext(policy: try MachineFixtures.policy(
                    nodes: selected.nodes, depth: selected.depth))
                var failure: MachineDefinitionFailure?
                do {
                    if erased { try context.lower(ErasedPairMachine(a, b)) }
                    else { try context.lower(TupleMachine(a, b)) }
                } catch { failure = error }
                #expect(failure == selected.expectedFailure)
                #expect(first.snapshot.contents == selected.firstCalls)
                #expect(second.snapshot.contents == selected.secondCalls)
            }
        }
    }
}
