import Testing
import MechanicsCore
import MechanicsModel
import MechanicsJoints
import MechanicsCompiler

@Suite struct ValidationTests {
    @Test func invalidIdentityAndTopologyCatalog() throws {
        let compiler = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()), policy = try CompilerFixtures.policy()
        let root = try CompilerFixtures.body("root", mode: .static)
        let duplicate = try CompilerFixtures.descriptor(bodies: [root, root], joints: [])
        CompilerFixtures.failure(.duplicateIdentity, record: root.id) { () throws(CompilationFailure) in _ = try compiler.compile(duplicate, policy: policy) }
        let dangling = try CompilerFixtures.descriptor(joints: [CompilerFixtures.joint(child: "missing")])
        CompilerFixtures.failure(.danglingReference, record: try CompilerFixtures.id(.joint, "hinge")) { () throws(CompilationFailure) in _ = try compiler.compile(dangling, policy: policy) }
        let disconnected = try CompilerFixtures.descriptor(joints: [])
        CompilerFixtures.failure(.disconnectedTree) { () throws(CompilationFailure) in _ = try compiler.compile(disconnected, policy: policy) }
        let multiple = try CompilerFixtures.descriptor(joints: [CompilerFixtures.joint("a"), CompilerFixtures.joint("b")], q: [0,0], v: [0,0])
        CompilerFixtures.failure(.multipleParents) { () throws(CompilationFailure) in _ = try compiler.compile(multiple, policy: policy) }
        let cycle = try CompilerFixtures.descriptor(joints: [CompilerFixtures.joint("a"), CompilerFixtures.joint("b", parent: "child", child: "root")], q: [0,0], v: [0,0])
        CompilerFixtures.failure(.unsupportedClosedLoop) { () throws(CompilationFailure) in _ = try compiler.compile(cycle, policy: policy) }
    }

    @Test func zeroVelocityDoesNotProveStructuralStaticOrKinematicMode() throws {
        let compiler = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()), policy = try CompilerFixtures.policy()
        let staticChild = try CompilerFixtures.descriptor(bodies: [CompilerFixtures.body("root", mode: .static), CompilerFixtures.body("child", mode: .static)])
        CompilerFixtures.failure(.incompatibleBodyMode, record: try CompilerFixtures.id(.body, "child")) { () throws(CompilationFailure) in _ = try compiler.compile(staticChild, policy: policy) }
        let grandchild = try CompilerFixtures.descriptor(bodies: [CompilerFixtures.body("root", mode: .static), CompilerFixtures.body("child"), CompilerFixtures.body("grandchild", mode: .static)],
            joints: [CompilerFixtures.joint(), CompilerFixtures.joint("weld", parent: "child", child: "grandchild", specification: .fixed, authority: .fixed)])
        CompilerFixtures.failure(.incompatibleBodyMode, record: try CompilerFixtures.id(.body, "grandchild")) { () throws(CompilationFailure) in _ = try compiler.compile(grandchild, policy: policy) }
        let kinematic = try CompilerFixtures.descriptor(bodies: [CompilerFixtures.body("root", mode: .static), CompilerFixtures.body("child", mode: .prescribedKinematic)])
        CompilerFixtures.failure(.incompatibleBodyMode) { () throws(CompilationFailure) in _ = try compiler.compile(kinematic, policy: policy) }
        let prescribed = try CompilerFixtures.descriptor(bodies: kinematic.bodies, joints: [CompilerFixtures.joint(authority: .prescribedMotion)])
        let accepted = try compiler.compile(prescribed, policy: policy)
        #expect(accepted.report.structuralTreeRank.rank == 11) // Prescribed equations are outside this rank certificate.
        let wrongAuthority = try CompilerFixtures.descriptor(joints: [CompilerFixtures.joint(authority: .fixed)])
        CompilerFixtures.failure(.incompatibleCoordinateAuthority) { () throws(CompilationFailure) in _ = try compiler.compile(wrongAuthority, policy: policy) }
    }

    @Test func movingAnchorPathAndSampleAreValidated() throws {
        let joint = try CompilerFixtures.joint(specification: .fixed, authority: .fixed, parentPlacement: .prescribed)
        let sample = try PrescribedAnchorState(frame: joint.record.parentAnchor.frame, time: 0, motion: .stationary(pose: .identity))
        let descriptor = try CompilerFixtures.descriptor(bodies: [CompilerFixtures.body("root", mode: .static), CompilerFixtures.body("child", mode: .prescribedKinematic)],
            joints: [joint], q: [], v: [], anchors: [sample])
        let model = try CompilerFixtures.compile(descriptor)
        #expect(model.report.velocityCount == 0)
        let missing = try CompilerFixtures.descriptor(bodies: descriptor.bodies, joints: [joint], q: [], v: [])
        let policy = try CompilerFixtures.policy(), compiler = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        CompilerFixtures.failure(.invalidCoordinates) { () throws(CompilationFailure) in _ = try compiler.compile(missing, policy: policy) }
        let staticBody = try CompilerFixtures.descriptor(bodies: [CompilerFixtures.body("root", mode: .static), CompilerFixtures.body("child", mode: .static)],
            joints: [joint], q: [], v: [], anchors: [sample])
        CompilerFixtures.failure(.incompatibleBodyMode) { () throws(CompilationFailure) in _ = try compiler.compile(staticBody, policy: policy) }
    }

    @Test func policyPhysicalityRepresentationAndChartFailures() throws {
        let compiler = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()), policy = try CompilerFixtures.policy()
        let nonphysical = try CompilerFixtures.descriptor(bodies: [CompilerFixtures.body("root", mode: .static), CompilerFixtures.body("child", tensor: Matrix3(1,0,0,0,1,0,0,0,3), physicality: 0.5)])
        CompilerFixtures.failure(.invalidInertia, record: try CompilerFixtures.id(.body, "child")) { () throws(CompilationFailure) in _ = try compiler.compile(nonphysical, policy: policy) }
        let missing = try CompilerFixtures.descriptor(requirements: [BodyRepresentationRequirement(body: CompilerFixtures.id(.body, "child"), geometry: [.collisionGeometry], inertia: .none)])
        CompilerFixtures.failure(.missingRepresentation) { () throws(CompilationFailure) in _ = try compiler.compile(missing, policy: policy) }
        let counts = try CompilerFixtures.descriptor(q: [], v: [0])
        CompilerFixtures.failure(.invalidCoordinates) { () throws(CompilationFailure) in _ = try compiler.compile(counts, policy: policy) }
        let singularAxes = [try JointAxis(kind: .revolute, direction: .unitX), try JointAxis(kind: .revolute, direction: .unitY), try JointAxis(kind: .revolute, direction: .unitZ)]
        let singular = try CompilerFixtures.descriptor(joints: [CompilerFixtures.joint(specification: .custom(orderedAxes: singularAxes))], q: [0,Double.pi/2,0], v: [0,0,0])
        CompilerFixtures.failure(.invalidCoordinates, record: try CompilerFixtures.id(.joint, "hinge")) { () throws(CompilationFailure) in _ = try compiler.compile(singular, policy: policy) }
    }

    @Test func capacityFailureDoesNotPublishModelAndStaleStateIsRejected() throws {
        let descriptor = try CompilerFixtures.descriptor(), compiler = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        let smallRecords = try CompilerFixtures.policy(records: 1), smallPattern = try CompilerFixtures.policy(sparsity: 5), smallDependencies = try CompilerFixtures.policy(dependencies: 0)
        CompilerFixtures.failure(.capacityExceeded) { () throws(CompilationFailure) in _ = try compiler.compile(descriptor, policy: smallRecords) }
        CompilerFixtures.failure(.capacityExceeded) { () throws(CompilationFailure) in _ = try compiler.compile(descriptor, policy: smallPattern) }
        CompilerFixtures.failure(.capacityExceeded) { () throws(CompilationFailure) in _ = try compiler.compile(descriptor, policy: smallDependencies) }
        let model = try CompilerFixtures.compile(descriptor), stale = try KinematicState(revision: 0, time: 0, q: [0], v: [0], acceleration: [0])
        CompilerFixtures.failure(.staleRevision) { () throws(CompilationFailure) in _ = try model.makeState(stale) }
        CompilerFixtures.failure(.wrongModel) { () throws(CompilationFailure) in try model.validating(stamp: ModelStamp(identity: "another", revision: 1)) }
    }
    @Test func cancelledCompilationReturnsFailureWithoutModel() async throws {
        let descriptor = try CompilerFixtures.descriptor(), policy = try CompilerFixtures.policy()
        let compiler = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        let task = Task { () -> Result<CompiledMechanicalModel, CompilationFailure> in
            withUnsafeCurrentTask { current in
                #expect(current != nil)
                current?.cancel()
            }
            do throws(CompilationFailure) { return .success(try compiler.compile(descriptor, policy: policy)) }
            catch { return .failure(error) }
        }
        switch await task.value {
        case .success:
            Issue.record("Cancelled compilation published a model.")
        case .failure(let failure):
            #expect(failure.diagnostics.first?.code == .cancelled)
            #expect(failure.diagnostics.first?.stage == .input)
        }
    }
}
