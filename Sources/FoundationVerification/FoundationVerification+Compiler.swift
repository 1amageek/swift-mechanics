import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints
import MechanicsCompiler

extension FoundationVerification {
    static func verifyCompiler() throws {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 1e-12)
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 2,
            maximumVelocities: 1, maximumJacobianScalars: 12),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-9,
                characteristicLengthMeters: 1), inertiaPolicy: inertiaPolicy,
            translationTolerance: tolerance, rotationTolerance: tolerance, maximumRecords: 20,
            maximumIdentifierBytes: 2000, maximumSparsityEntries: 12, maximumDependencyEntries: 200,
            maximumExtensionRecords: 1, maximumDiagnostics: 4,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: compilerVerificationTarget)
        let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        let input = try compilerDescriptor(inertiaPolicy: inertiaPolicy, displacedChild: false)
        let compiled = try compiler.compile(input, policy: policy)
        let child = try EntityID(kind: .body, key: "compile-probe-child")
        let extensionRecord = try MechanicalExtensionRecord(id: EntityID(kind: .load, key: "compile-probe-load"),
            schema: "probe.stiffness", references: [child], parameters: [ExtensionParameter(name: "stiffness",
                value: 2, dimension: PhysicalDimension(mass: 1, time: -2))])
        let extensionCompiler: any MechanicalModelCompiling = try ReferenceMechanicalCompiler(extensions: RuntimeCompilerValidator())
        let extended = try extensionCompiler.compile(compilerDescriptor(inertiaPolicy: inertiaPolicy,
            displacedChild: false, extensions: [extensionRecord]), policy: policy)
        guard extended.extensionEvidence.count == 1, extended.extensionEvidence[0].work.operations == 12,
              extended.extensionEvidence[0].work.peakScalarStorage == 1 else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let snapshot = try compiled.evaluate(compiled.makeState(input.initialState))
        guard compiled.report.positionCount == 1, compiled.report.velocityCount == 1,
              compiled.report.structuralTreeRank.rank == 11, compiled.sparsity.rowCount == 12,
              try compiled.sparsity.contains(row: 6, column: 0),
              try !compiled.sparsity.contains(row: 0, column: 0),
              try snapshot.body(child).motion.velocity.angular == (try Vector3(0,0,2)),
              compiled.manifest.entries[0].qualification == .descriptorValidated(modelRevision: 1) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        var staleRejected = false
        do throws(CompilationFailure) {
            let stale = try compilerState(revision: 2)
            _ = try compiled.makeState(stale)
        } catch {
            guard error.diagnostics[0].code == .staleRevision else { throw FoundationVerificationError.analyticCheckFailed }
            staleRejected = true
        }
        var poseRejected = false
        do throws(CompilationFailure) {
            let invalid = try compilerDescriptor(inertiaPolicy: inertiaPolicy, displacedChild: true)
            _ = try compiler.compile(invalid, policy: policy)
        } catch {
            guard error.diagnostics[0].code == .inconsistentInitialPose else { throw FoundationVerificationError.analyticCheckFailed }
            poseRejected = true
        }
        guard staleRejected, poseRejected else { throw FoundationVerificationError.analyticCheckFailed }
    }

    static var compilerVerificationTarget: CompilerTarget {
        #if arch(wasm32)
        #if hasFeature(Embedded)
        .embeddedWasiPreview1
        #else
        .wasiPreview1
        #endif
        #else
        .nativeCPU
        #endif
    }

    private static func compilerState(revision: UInt64) throws(CompilationFailure) -> KinematicState {
        do { return try KinematicState(revision: revision, time: 0, q: [0], v: [2], acceleration: [0]) }
        catch { throw .one(.invalidCoordinates, .coordinates, message: "Verification state construction failed.") }
    }

    static func compilerDescriptor(inertiaPolicy: InertiaValidationPolicy,
                                           displacedChild: Bool,
                                           extensions: [MechanicalExtensionRecord] = []) throws(CompilationFailure) -> MechanicalDescriptor {
        do {
            let root = try BodyRecord3D(id: EntityID(kind: .body, key: "compile-probe-root"),
                frame: EntityID(kind: .frame, key: "compile-probe-root-frame"), mode: .static,
                bodyToWorld: .identity, representations: BodyRepresentations(), inertia: nil)
            let child = try BodyRecord3D(id: EntityID(kind: .body, key: "compile-probe-child"),
                frame: EntityID(kind: .frame, key: "compile-probe-child-frame"), mode: .dynamic,
                bodyToWorld: RigidTransform(rotation: .identity, translation: displacedChild ? .unitX : .zero),
                representations: BodyRepresentations(), inertia: InertialRepresentation3D(
                    properties: MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .identity, policy: inertiaPolicy),
                    provenance: SourceProvenance(source: "analytic-probe", revision: 1), quality: .exact))
            let joint = try JointRecord(id: EntityID(kind: .joint, key: "compile-probe-hinge"),
                parentBody: root.id, childBody: child.id,
                parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "compile-probe-pa"), placement: .fixed(.identity)),
                childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "compile-probe-ca"), placement: .fixed(.identity)),
                manifold: JointManifold(.revolute(axis: .unitZ)))
            return try MechanicalDescriptor(identity: "compiler-runtime-probe", revision: 1,
                bodies: [.spatial(child), .spatial(root)], joints: [MechanicalJoint(record: joint, authority: .dynamicState)],
                root: root.id, rootBase: .fixed, rootAuthority: .fixed,
                worldFrame: EntityID(kind: .frame, key: "compile-probe-world"), initialState: compilerState(revision: 1),
                representationRequirements: [], features: [], extensions: extensions)
        } catch {
            throw .one(.invalidInput, .input, message: "Verification descriptor construction failed.")
        }
    }
}
