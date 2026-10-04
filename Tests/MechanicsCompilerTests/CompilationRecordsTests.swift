import SwiftMechanics
import Testing

@Suite struct CompilationRecordsTests {
    @Test func independentStructuralRanksAndFloatingCounts() throws {
        let spatial = try CompilerFixtures.compile(CompilerFixtures.descriptor())
        #expect(spatial.report.structuralTreeRank.ambientBodyVelocityCount == 12)
        #expect(spatial.report.structuralTreeRank.rank == 11)
        #expect(spatial.report.velocityCount == 1)
        let planar = try CompilerFixtures.compile(CompilerFixtures.descriptor(bodies: [CompilerFixtures.body("root", planar: true, mode: .static), CompilerFixtures.body("child", planar: true)]))
        #expect(planar.report.structuralTreeRank.ambientBodyVelocityCount == 6)
        #expect(planar.report.structuralTreeRank.rank == 5)
        let spatialFree = try CompilerFixtures.compile(CompilerFixtures.descriptor(bodies: [CompilerFixtures.body("root")], joints: [], base: .spatialFloating,
            authority: .dynamicState, q: [0,0,0,1,0,0,0], v: [0,0,0,0,0,0]))
        #expect(spatialFree.report.positionCount == 7)
        #expect(spatialFree.report.velocityCount == 6)
        #expect(spatialFree.report.structuralTreeRank.rank == 0)
        let planarFree = try CompilerFixtures.compile(CompilerFixtures.descriptor(bodies: [CompilerFixtures.body("root", planar: true)], joints: [], base: .planarFloating,
            authority: .dynamicState, q: [0,0,0], v: [0,0,0]))
        #expect(planarFree.report.positionCount == 3)
        #expect(planarFree.report.velocityCount == 3)
        #expect(planarFree.report.structuralTreeRank.rank == 0)
    }

    @Test func canonicalLayoutReconstructionAndActualPattern() throws {
        let source = try CompilerFixtures.descriptor(bodies: [CompilerFixtures.body("child", display: "mesh"), CompilerFixtures.body("root", mode: .static)])
        let model = try CompilerFixtures.compile(source)
        let reverse = try CompilerFixtures.descriptor(bodies: Array(source.bodies.reversed()))
        let other = try CompilerFixtures.compile(reverse)
        #expect(model.tree.layout == other.tree.layout)
        #expect(model.sparsity == other.sparsity)
        #expect(source.bodies[0].representations.displayGeometry?.assetKey == "mesh")
        #expect(model.descriptor.bodies.first?.representations.displayGeometry?.assetKey == "mesh")
        let reconstructed = try CompilerFixtures.compile(model.descriptor)
        #expect(reconstructed.tree.layout == model.tree.layout)
        #expect(model.sparsity.rowCount == 12 && model.sparsity.columnCount == 1)
        #expect(model.sparsity.columnIndices == Array(repeating: 0, count: 6))
        #expect(model.sparsity.rowOffsets == [0,0,0,0,0,0,0,1,2,3,4,5,6])
        let snapshot = model.initialSnapshot
        let columns = try snapshot.geometricColumns(body: CompilerFixtures.id(.body, "child"))
        #expect(columns.count == 1)
        #expect(columns.first?.angular.z == 1)
        #expect(try model.sparsity.contains(row: 8, column: 0))
        #expect(try !model.sparsity.contains(row: 2, column: 0))
        #expect(source.initialState.q == [0])
    }

    @Test func actualStateMotionAndImmutableIndependentModels() throws {
        let source = try CompilerFixtures.descriptor(bodies: [CompilerFixtures.body("root", mode: .static),
            CompilerFixtures.body("child", pose: RigidTransform(rotation: .identity, translation: .unitX))],
            joints: [CompilerFixtures.joint(childPlacement: .fixed(RigidTransform(rotation: .identity, translation: Vector3(-1, 0, 0))))])
        let model = try CompilerFixtures.compile(source)
        let left = try model.makeState(KinematicState(revision: 1, time: 0.2, q: [0], v: [2], acceleration: [4]))
        let right = try model.makeState(KinematicState(revision: 1, time: 0.8, q: [Double.pi/2], v: [-1], acceleration: [0]))
        let child = try CompilerFixtures.id(.body, "child")
        let first = try model.evaluate(left).body(child).motion
        let second = try model.evaluate(right).body(child).motion
        #expect(first.pose.translation == .unitX)
        #expect(first.velocity.linear == (try Vector3(0, 2, 0)))
        #expect(first.acceleration.linear == (try Vector3(-4, 4, 0)))
        #expect(first.velocity.angular.z == 2 && first.acceleration.angular.z == 4)
        #expect(abs(second.pose.translation.x) < 1e-11 && abs(second.pose.translation.y - 1) < 1e-11)
        #expect(abs(second.velocity.linear.x - 1) < 1e-11 && abs(second.velocity.linear.y) < 1e-11)
        #expect(abs(second.acceleration.linear.x) < 1e-11 && abs(second.acceleration.linear.y + 1) < 1e-11)
        #expect(left.state.q == [0] && model.descriptor.initialState.q == [0])
    }

    @Test func equivalentQuaternionSignAndSourcePoseFailure() throws {
        let equivalent = try CompilerFixtures.descriptor(bodies: [CompilerFixtures.body("root", mode: .static),
            CompilerFixtures.body("child", pose: RigidTransform(rotation: UnitQuaternion.identity.negated(), translation: .zero))])
        _ = try CompilerFixtures.compile(equivalent)
        #expect(try equivalent.bodies[1].kinematicBody().referencePose.rotation.w == -1)
        let bad = try CompilerFixtures.descriptor(bodies: [CompilerFixtures.body("root", mode: .static),
            CompilerFixtures.body("child", pose: RigidTransform(rotation: .identity, translation: .unitX))])
        let policy = try CompilerFixtures.policy(), child = try CompilerFixtures.id(.body, "child")
        CompilerFixtures.failure(.inconsistentInitialPose, record: child) { () throws(CompilationFailure) in _ = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(bad, policy: policy) }
    }
}
