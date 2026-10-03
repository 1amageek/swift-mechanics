import Testing
import MechanicsCore
import MechanicsModel
import MechanicsJoints
import MechanicsCompiler

@Suite struct RevisionsTests {
    @Test func displayAndInertiaEditsPreserveActualStateAndSelectiveDependencies() throws {
        let source = try CompilerFixtures.compile(CompilerFixtures.descriptor()), updater = ReferenceModelRevisionUpdater()
        let display = try CompilerFixtures.compile(CompilerFixtures.descriptor(revision: 2, bodies: [CompilerFixtures.body("root", mode: .static), CompilerFixtures.body("child", display: "updated-mesh")]))
        let transition = try updater.transition(from: source, to: display, policy: .preserveIfKinematicsUnchanged)
        let child = try CompilerFixtures.id(.body, "child")
        #expect(transition.kind == .parameters)
        #expect(transition.invalidatedCaches == [CompiledCacheKey(kind: .displayRepresentation, entity: child)])
        let state = try source.makeState(KinematicState(revision: 1, time: 2, q: [0.4], v: [3], acceleration: [5]))
        let migrated = try updater.migrate(state, using: transition, to: display)
        #expect(migrated.stamp.revision == 2 && migrated.state.q == state.state.q)
        #expect(try display.evaluate(migrated).body(child).motion.velocity.angular.z == 3)
        #expect(state.stamp.revision == 1 && state.state.q == [0.4])
        CompilerFixtures.failure(.staleRevision) { () throws(CompilationFailure) in _ = try display.evaluate(state) }
        let mass = try CompilerFixtures.compile(CompilerFixtures.descriptor(revision: 3, bodies: [CompilerFixtures.body("root", mode: .static), CompilerFixtures.body("child", mass: 2, display: "updated-mesh")]))
        let massTransition = try updater.transition(from: display, to: mass, policy: .preserveIfKinematicsUnchanged)
        #expect(massTransition.invalidatedCaches == [CompiledCacheKey(kind: .bodyInertia, entity: child)])
        _ = try updater.migrate(migrated, using: massTransition, to: mass)
    }
    @Test func equalCountsDoNotAdmitChangedAxesOrAuthorityAndResetIsExplicit() throws {
        let source = try CompilerFixtures.compile(CompilerFixtures.descriptor()), updater = ReferenceModelRevisionUpdater()
        let changed = try CompilerFixtures.compile(CompilerFixtures.descriptor(revision: 2, joints: [CompilerFixtures.joint(specification: .revolute(axis: .unitX))]))
        #expect(source.report.velocityCount == changed.report.velocityCount)
        CompilerFixtures.failure(.incompatibleMigration) { () throws(CompilationFailure) in _ = try updater.transition(from: source, to: changed, policy: .preserveIfKinematicsUnchanged) }
        let reset = try updater.transition(from: source, to: changed, policy: .reset)
        #expect(reset.compatibility == .requiresReset)
        let state = try source.makeState(source.descriptor.initialState)
        CompilerFixtures.failure(.resetRequired) { () throws(CompilationFailure) in _ = try updater.migrate(state, using: reset, to: changed) }
        _ = try changed.makeState(changed.descriptor.initialState)
        let prescribed = try CompilerFixtures.compile(CompilerFixtures.descriptor(revision: 2, joints: [CompilerFixtures.joint(authority: .prescribedMotion)]))
        CompilerFixtures.failure(.incompatibleMigration) { () throws(CompilationFailure) in _ = try updater.transition(from: source, to: prescribed, policy: .preserveIfKinematicsUnchanged) }
    }
    @Test func topologyMonotonicRevisionAndExactTargetBinding() throws {
        let source = try CompilerFixtures.compile(CompilerFixtures.descriptor()), updater = ReferenceModelRevisionUpdater()
        CompilerFixtures.failure(.staleRevision) { () throws(CompilationFailure) in _ = try updater.transition(from: source, to: source, policy: .reset) }
        let topology = try CompilerFixtures.compile(CompilerFixtures.descriptor(revision: 2, bodies: [CompilerFixtures.body("root", mode: .static)], joints: [], q: [], v: []))
        let reset = try updater.transition(from: source, to: topology, policy: .reset)
        #expect(reset.kind == .topology && reset.invalidatedCaches.contains(CompiledCacheKey(kind: .stateLayout, entity: nil)))
        let target = try CompilerFixtures.compile(CompilerFixtures.descriptor(revision: 2)), sameStampDifferentSnapshot = try CompilerFixtures.compile(CompilerFixtures.descriptor(revision: 2, bodies: [CompilerFixtures.body("root", mode: .static), CompilerFixtures.body("child", mass: 9)]))
        let transition = try updater.transition(from: source, to: target, policy: .preserveIfKinematicsUnchanged)
        #expect(transition.kind == .revisionOnly && transition.invalidatedCaches.isEmpty)
        let state = try source.makeState(source.descriptor.initialState)
        CompilerFixtures.failure(.mismatchedTransition) { () throws(CompilationFailure) in _ = try updater.migrate(state, using: transition, to: sameStampDifferentSnapshot) }
        let unrelated = try CompilerFixtures.compile(CompilerFixtures.descriptor(revision: 2, identity: "another"))
        CompilerFixtures.failure(.wrongModel) { () throws(CompilationFailure) in _ = try updater.transition(from: source, to: unrelated, policy: .reset) }
    }
    @Test func canonicalEquivalentSiblingIDsKeepActualCoordinateMeaning() throws {
        let decomposed = "cafe\u{301}", composed = "café"
        #expect(decomposed == composed)
        let firstPose = RigidTransform(rotation: try UnitQuaternion(axis: .unitZ, angle: 0.7), translation: .zero)
        let secondPose = RigidTransform(rotation: try UnitQuaternion(axis: .unitZ, angle: 0.2), translation: .zero)
        let bodies = try [CompilerFixtures.body("root", mode: .static), CompilerFixtures.body("a", pose: firstPose), CompilerFixtures.body("b", pose: secondPose)]
        let source = try CompilerFixtures.compile(CompilerFixtures.descriptor(bodies: bodies,
            joints: [CompilerFixtures.joint(composed, child: "a"), CompilerFixtures.joint("cafg", child: "b")], q: [0.2,0.7], v: [0,0]))
        let target = try CompilerFixtures.compile(CompilerFixtures.descriptor(revision: 2, bodies: Array(bodies.reversed()),
            joints: [CompilerFixtures.joint("cafg", child: "b"), CompilerFixtures.joint(decomposed, child: "a")], q: [0.2,0.7], v: [0,0]))
        #expect(source.tree.layout == target.tree.layout)
        #expect(source.tree.layout.joints.first?.joint.key == "cafg")
        let updater = ReferenceModelRevisionUpdater(), transition = try updater.transition(from: source, to: target, policy: .preserveIfKinematicsUnchanged)
        #expect(transition.kind == .revisionOnly)
        let state = try source.makeState(KinematicState(revision: 1, time: 1, q: [0.3,0.4], v: [1,2], acceleration: [0,0]))
        let migrated = try updater.migrate(state, using: transition, to: target)
        for key in ["a", "b"] {
            let id = try CompilerFixtures.id(.body, key)
            let oldMotion = try source.evaluate(state).body(id).motion
            let newMotion = try target.evaluate(migrated).body(id).motion
            #expect(oldMotion == newMotion)
        }
        #expect(migrated.state.q == [0.3,0.4])
    }
}
