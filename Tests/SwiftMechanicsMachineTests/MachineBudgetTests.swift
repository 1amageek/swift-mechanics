import SwiftMechanics
import Testing

struct MachineBudgetTests {
    @available(macOS 15.0, *)
    @Test func lazyExpansionIsBoundedBeforeClosures() throws {
        let counter = MachineCounter(), body = try MachineFixtures.body("child")
        let expansion = ForEachMachine(0..<5, id: { index in counter.identity(); return String(index) }) { _ in
            counter.content(); return MachineBody(body)
        }
        #expect(counter.snapshot.contents == 0)
        let definition = try MachineFixtures.definition { expansion }
        var published: MechanicalDescriptor?
        do { published = try definition.makeDescriptor(policy: MachineFixtures.policy(iterations: 2)); Issue.record("Iteration budget must reject expansion.") }
        catch MachineDefinitionFailure.capacityExceeded {}
        #expect(published == nil)
        #expect(counter.snapshot.identities == 2)
        #expect(counter.snapshot.contents == 2)
        let complete = try definition.makeDescriptor(policy: MachineFixtures.policy(iterations: 5))
        #expect(complete.bodies.count == 5)
        #expect(counter.snapshot.contents == 7)
    }

    @Test func duplicateAndFailedDefinitionsAreNotPublished() throws {
        let body = try MachineFixtures.body("root", mode: .static)
        let duplicate = try MachineFixtures.definition { MachineBody(body); MachineBody(body) }
        var published: MechanicalDescriptor?
        do { published = try duplicate.makeDescriptor(policy: MachineFixtures.policy()); Issue.record("Duplicate body must fail.") }
        catch MachineDefinitionFailure.duplicateIdentity(let id) { #expect(id == body.id) }
        #expect(published == nil)
        let valid = try MachineFixtures.definition(q: []) { MachineBody(body) }
        #expect(try valid.makeDescriptor(policy: MachineFixtures.policy()).bodies.count == 1)
        do { _ = try valid.makeDescriptor(policy: MachineFixtures.policy(records: 2)); Issue.record("World plus body and frame must exceed two identities.") }
        catch MachineDefinitionFailure.capacityExceeded {}
        do { _ = try valid.makeDescriptor(policy: MachineFixtures.policy(bytes: 4)); Issue.record("World plus body bytes must exceed budget.") }
        catch MachineDefinitionFailure.capacityExceeded {}
        do { _ = try valid.makeDescriptor(policy: MachineFixtures.policy(nodes: 0)); Issue.record("Zero node budget must fail before lowering.") }
        catch MachineDefinitionFailure.capacityExceeded {}
    }

    @Test func recursiveUserBodyIsDepthBounded() throws {
        let definition = try MachineFixtures.definition { RecursiveMachine() }
        do { _ = try definition.makeDescriptor(policy: MachineFixtures.policy(depth: 4)); Issue.record("Recursive body must exhaust depth.") }
        catch MachineDefinitionFailure.depthExceeded {}
    }

    @available(macOS 15.0, *)
    @Test func concreteBoxRetainsAndReleasesContent() throws {
        let counter = MachineCounter(), record = try MachineFixtures.body("root", mode: .static)
        var first: AnyMachine? = AnyMachine(LifetimeMachine(counter: counter, record: record))
        var second = first
        first = nil
        #expect(counter.snapshot.releases == 0)
        if let second {
            let definition = try MachineFixtures.definition(q: []) { second }
            #expect(try definition.makeDescriptor(policy: MachineFixtures.policy()).bodies.count == 1)
        }
        second = nil
        #expect(counter.snapshot.releases == 1)
    }
}
