import SwiftMechanics
import Testing

struct MachineBuilderTests {
    @Test func branchesLoopsAndErasurePreserveSelectedOrder() throws {
        let records = try (0..<7).map { try MachineFixtures.body("b" + String($0)) }
        let optional = try MachineFixtures.body("optional")
        let enabled = BranchMachine(records: records, optional: optional, enabled: true, selection: 0)
        let definition = try MachineFixtures.definition { AnyMachine(enabled) }
        let descriptor = try definition.makeDescriptor(policy: MachineFixtures.policy())
        #expect(descriptor.bodies.map { $0.id.key } == ["b0", "optional", "b1", "b3", "b5", "b6"])
        let alternate = try MachineFixtures.definition { BranchMachine(records: records, optional: nil, enabled: false, selection: 1) }
        #expect(try alternate.makeDescriptor(policy: MachineFixtures.policy()).bodies.map { $0.id.key } == ["b0", "b2", "b4", "b5", "b6"])
        let emptySwitch = try MachineFixtures.definition { BranchMachine(records: records, optional: nil, enabled: true, selection: 2) }
        #expect(try emptySwitch.makeDescriptor(policy: MachineFixtures.policy()).bodies.map { $0.id.key } == ["b0", "b1", "b5", "b6"])
        let erased: [AnyMachine] = [AnyMachine(MachineBody(records[0])), AnyMachine(MachineGroup { MachineBody(records[1]); EmptyMachine() })]
        let heterogeneous = try MachineFixtures.definition { ArrayMachine(erased) }
        #expect(try heterogeneous.makeDescriptor(policy: MachineFixtures.policy()).bodies.map { $0.id.key } == ["b0", "b1"])
    }

    @Test func emptyDeclarationsAndNestedErasure() throws {
        let empty = try MachineFixtures.definition(q: []) { MachineGroup {}; for _ in 0..<0 { EmptyMachine() } }
        #expect(try empty.makeDescriptor(policy: MachineFixtures.policy()).bodies.isEmpty)
        let body = try MachineFixtures.body("single")
        let availability = try MachineFixtures.definition { AvailabilityMachine(record: body) }
        #expect(try availability.makeDescriptor(policy: MachineFixtures.policy()).bodies.count == 1)
        let single = try MachineFixtures.definition { AnyMachine(AnyMachine(MachineBody(body))) }
        #expect(try single.makeDescriptor(policy: MachineFixtures.policy()).bodies.count == 1)
    }
}
