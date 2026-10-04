import SwiftMechanics
import Testing

struct MachineCompilationTests {
    @Test func realDescriptorCompilerAndHingeMotion() throws {
        let machine = try HingeMachine(root: MachineFixtures.body("root", mode: .static), child: MachineFixtures.body("child"), hinge: MachineFixtures.hinge())
        let definition = try MachineFixtures.definition { machine }
        let descriptor = try definition.makeDescriptor(policy: MachineFixtures.policy())
        #expect(descriptor.bodies.map { $0.id.key } == ["root", "child"])
        #expect(descriptor.joints == [machine.hinge])
        let compiled = try definition.compile(using: ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()), definitionPolicy: MachineFixtures.policy(), compilationPolicy: MachineFixtures.compilationPolicy())
        #expect(compiled.report.bodyCount == 2)
        #expect(compiled.report.jointCount == 1)
        let state = try compiled.makeState(KinematicState(revision: 1, time: 0, q: [0.4], v: [2], acceleration: [0]))
        let motion = try compiled.evaluate(state).body(machine.child.id).motion
        #expect(abs(try motion.pose.rotation.rotationVector().z - 0.4) < 1e-10)
        #expect(abs(motion.velocity.angular.z - 2) < 1e-10)
    }

    @Test func repeatedInstancesConnectToAbsoluteRoot() throws {
        let root = try MachineFixtures.body("root", mode: .static), child = try MachineFixtures.body("child"), hinge = try MachineFixtures.hinge()
        let definition = try MachineFixtures.definition(q: [0, 0]) {
            MachineBody(root)
            MachineInstance(id: "left") { MachineBody(child); MachineJoint(hinge, parent: .absolute(root.id)) }
            MachineInstance(id: "right") { MachineBody(child); MachineJoint(hinge, parent: .absolute(root.id)) }
        }
        let descriptor = try definition.makeDescriptor(policy: MachineFixtures.policy())
        let left = try MachineDefinitionContext.scopedIdentity(child.id, namespace: ["left"])
        let right = try MachineDefinitionContext.scopedIdentity(child.id, namespace: ["right"])
        #expect(descriptor.bodies.map { $0.id } == [root.id, left, right])
        #expect(descriptor.joints.map { $0.record.childBody } == [left, right])
        #expect(descriptor.joints.allSatisfy { $0.record.parentBody == root.id })
        let compiled = try definition.compile(definitionPolicy: MachineFixtures.policy(), compilationPolicy: MachineFixtures.compilationPolicy())
        let state = try compiled.makeState(KinematicState(revision: 1, time: 0, q: [0.2, 0.5], v: [1, 2], acceleration: [0, 0]))
        let snapshot = try compiled.evaluate(state)
        let velocities = try [snapshot.body(left).motion.velocity.angular.z, snapshot.body(right).motion.velocity.angular.z].sorted()
        #expect(velocities == [1, 2])
    }

    @Test func compilerFailurePublishesNoModel() throws {
        let child = try MachineFixtures.body("child")
        let invalid = try MachineFixtures.definition { MachineBody(child) }
        var published: CompiledMechanicalModel?
        do { published = try invalid.compile(definitionPolicy: MachineFixtures.policy(), compilationPolicy: MachineFixtures.compilationPolicy()); Issue.record("Missing root must fail compiler admission.") }
        catch MachineDefinitionFailure.compilation(let failure) { #expect(failure.diagnostics.first?.code == .invalidRoot) }
        #expect(published == nil)
    }
}
