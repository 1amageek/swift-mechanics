import SwiftMechanics
import Testing

struct MachineIdentityTests {
    @available(macOS 15.0, *)
    @Test func duplicateEmptyInstanceAndLazyIdentityFail() throws {
        let repeated = try MachineFixtures.definition { MachineInstance(id: "same") {}; MachineInstance(id: "same") {} }
        do { _ = try repeated.makeDescriptor(policy: MachineFixtures.policy()); Issue.record("Repeated empty instance must still fail.") }
        catch MachineDefinitionFailure.duplicateInstance {}
        let counter = MachineCounter()
        let repeatedLazy = try MachineFixtures.definition {
            ForEachMachine(0..<2, id: { _ in "same" }) { _ in counter.content(); return EmptyMachine() }
        }
        do { _ = try repeatedLazy.makeDescriptor(policy: MachineFixtures.policy()); Issue.record("Repeated explicit iteration identity must fail.") }
        catch MachineDefinitionFailure.duplicateInstance {}
        #expect(counter.snapshot.contents == 1)
    }

    @Test func scopedKeysAreInjectiveAndCanonicallyStable() throws {
        let local = try MachineFixtures.id(.body, "child")
        let first = try MachineDefinitionContext.scopedIdentity(local, namespace: ["a", "b"])
        let second = try MachineDefinitionContext.scopedIdentity(local, namespace: ["a:b"])
        #expect(first != second)
        let composed = try MachineDefinitionContext.scopedIdentity(local, namespace: ["é"])
        let decomposed = try MachineDefinitionContext.scopedIdentity(local, namespace: ["e\u{301}"])
        #expect(composed == decomposed)
        #expect(try MachineDefinitionContext.scopedIdentity(local, namespace: []) == local)
        let invalid = try MachineFixtures.definition { MachineInstance(id: "") {} }
        do { _ = try invalid.makeDescriptor(policy: MachineFixtures.policy()); Issue.record("Empty namespace must fail.") }
        catch MachineDefinitionFailure.invalidNamespace {}
        let reserved = try MachineFixtures.body("!machine:reserved")
        let definition = try MachineFixtures.definition { MachineBody(reserved) }
        do { _ = try definition.makeDescriptor(policy: MachineFixtures.policy()); Issue.record("Reserved root identity must fail.") }
        catch MachineDefinitionFailure.reservedIdentity(let id) { #expect(id == reserved.id) }
    }

    @Test func invalidAbsoluteEndpointIsTypedJointFailure() throws {
        let joint = try MachineFixtures.hinge(), frame = try MachineFixtures.id(.frame, "invalid-parent")
        let invalid = try MachineFixtures.definition { MachineJoint(joint, parent: .absolute(frame)) }
        do { _ = try invalid.makeDescriptor(policy: MachineFixtures.policy()); Issue.record("Frame endpoint must fail.") }
        catch MachineDefinitionFailure.invalidJoint(let failure) { #expect(failure == .identityKindMismatch) }
    }
}
