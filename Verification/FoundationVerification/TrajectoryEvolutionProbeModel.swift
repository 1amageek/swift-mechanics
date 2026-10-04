import SwiftMechanics

/// Genuine compiler source for a law-bound prescribed root and an optional dynamic child.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class TrajectoryEvolutionProbeModel: Sendable {
    let model: CompiledMechanicalModel
    let program: PrescribedBaseTrajectoryProgram
    let layout: ConstraintCoordinateLayout
    let planar: Bool
    let piecewise: Bool
    let descendant: Bool
    let futureAngularOffset: Double
    let descendantDrive: Double
    let root: EntityID
    let rootFrame: EntityID
    let worldFrame: EntityID
    let mass: Double
    let center: Vector3
    let inertiaAtCenter: Matrix3
    let descendantBody: EntityID?
    let descendantFrame: EntityID?
    let descendantJoint: EntityID?
    let descendantPosition: Int?
    let descendantVelocity: Int?
    let descendantMass: Double
    let descendantCenter: Vector3
    let descendantInertiaAtCenter: Matrix3
    let drive: [Double]

    @inline(never)
    init(planar: Bool, piecewise: Bool, descendant: Bool = false,
         futureAngularOffset: Double = 0, descendantDrive: Double = 0) throws {
        guard futureAngularOffset.isFinite, descendantDrive.isFinite,
              piecewise || futureAngularOffset == 0, descendant || descendantDrive == 0 else {
            throw RuntimeFailure(.invalidInput, message: "Future-law changes require a piecewise law; child effort requires a child.")
        }
        let mass = 2.0, center = try Vector3(0.4, -0.3, planar ? 0 : 0.2)
        let inertia = try Matrix3(3, 0, 0, 0, 4, 0, 0, 0, 5)
        let childMass = 1.0, childCenter = try Vector3(0.2, -0.1, planar ? 0 : 0.15)
        let childInertia = try Matrix3(2, 0, 0, 0, 3, 0, 0, 0, 4)
        let root = try EntityID(kind: .body, key: "af26-trajectory-root")
        let program = try Self.program(planar: planar, piecewise: piecewise, futureAngularOffset: futureAngularOffset)
        let child = descendant ? try EntityID(kind: .body, key: "af26-trajectory-descendant") : nil
        let childFrame = descendant ? try EntityID(kind: .frame, key: "af26-trajectory-descendant-frame") : nil
        let joint = descendant ? try EntityID(kind: .joint, key: "af26-trajectory-prismatic") : nil
        let model = try Self.compile(program: program, planar: planar, root: root, mass: mass, center: center,
            inertia: inertia, child: child, childFrame: childFrame, joint: joint,
            childMass: childMass, childCenter: childCenter, childInertia: childInertia)
        let dimensions: [PhysicalDimension] = planar ? [.length, .length, .angle] :
            [.length, .length, .length, .angle, .angle, .angle]
        let rootScales: [Double] = planar ? [2, 3, 4] : [2, 3, 4, 5, 6, 7]
        let n = model.tree.layout.velocityCount
        let layout = try ConstraintCoordinateLayout(coordinateIDs: (0..<n).map { UInt64(801+$0) },
            dimensions: dimensions + (descendant ? [.length] : []),
            scales: rootScales + (descendant ? [2] : []), timeScale: 2, revision: model.stamp.revision)
        var effort = [Double](repeating: 0, count: n)
        let childPosition: Int?, childVelocity: Int?
        if let joint {
            guard let entry = model.tree.layout.joints.first(where: { $0.joint == joint }) else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            childPosition = entry.positions.start; childVelocity = entry.velocities.start
            effort[entry.velocities.start] = descendantDrive
        } else {
            childPosition = nil; childVelocity = nil
        }
        self.planar = planar; self.piecewise = piecewise; self.descendant = descendant
        self.futureAngularOffset = futureAngularOffset; self.descendantDrive = descendantDrive
        self.mass = mass; self.center = center; inertiaAtCenter = inertia
        descendantMass = childMass; descendantCenter = childCenter; descendantInertiaAtCenter = childInertia
        self.root = root; self.program = program; self.model = model; self.layout = layout
        rootFrame = program.trajectory.frame; worldFrame = program.trajectory.parentFrame
        descendantBody = child; descendantFrame = childFrame; descendantJoint = joint
        descendantPosition = childPosition; descendantVelocity = childVelocity; drive = effort
    }

    @inline(never)
    private static func program(planar: Bool, piecewise: Bool,
                                futureAngularOffset: Double) throws -> PrescribedBaseTrajectoryProgram {
        let policy = try PrescribedTrajectoryPolicy(motion: PrescribedMotionPolicy(maximumSamples: 1,
            maximumIdentifierBytes: 1024, maximumMetadataBytes: 32768), maximumSegments: 2)
        let trajectory = piecewise ? try Self.piecewise(policy: policy, futureAngularOffset: futureAngularOffset) :
            try Self.harmonic(planar: planar)
        var work = try GeometricProbeContext.work()
        return try PrescribedBaseTrajectoryProgram(trajectory: trajectory,
            layout: planar ? .planarFloating : .spatialFloating, policy: policy, work: &work)
    }

    @inline(never)
    private static func harmonic(planar: Bool) throws -> PrescribedTrajectory {
        .harmonic(try HarmonicPrescribedMotion(frame: EntityID(kind: .frame, key: "af26-harmonic-frame"),
            parentFrame: EntityID(kind: .frame, key: "af26-trajectory-parent"), referenceTime: 0,
            initialPose: RigidTransform(rotation: UnitQuaternion(axis: planar ? .unitZ : .unitX, angle: 0.4),
                translation: Vector3(1, 2, planar ? 0 : 3)),
            translationSine: Vector3(0.3, -0.2, planar ? 0 : 0.1),
            translationCosine: Vector3(0.1, 0.2, planar ? 0 : -0.1), rotationAxis: .unitZ,
            angularSine: 0.4, angularCosine: 0.2, frequency: 2, phase: 0.3,
            minimumTime: 0, maximumTime: 2, maximumIdentifierBytes: 1024))
    }

    @inline(never)
    private static func piecewise(policy: PrescribedTrajectoryPolicy,
                                  futureAngularOffset: Double) throws -> PrescribedTrajectory {
        let start = try jet(displacement: 0, rate: 0, acceleration: 0)
        let seam = try jet(displacement: 1, rate: 3, acceleration: 6)
        let end = try PrescribedMotionJet(displacement: Vector3(0, 1.125, 0), angle: 9+futureAngularOffset,
            linearVelocity: Vector3(0, 1.875, 0), angularRate: 15,
            linearAcceleration: Vector3(0, 2.25, 0), angularAcceleration: 18)
        let segments = [try PrescribedMotionSegment(startTime: 0, endTime: 1, start: start, end: seam),
            try PrescribedMotionSegment(startTime: 1, endTime: 2, start: seam, end: end)]
        var work = try GeometricProbeContext.work()
        return .piecewise(try PiecewisePrescribedMotion(frame: EntityID(kind: .frame, key: "af26-piecewise-frame"),
            parentFrame: EntityID(kind: .frame, key: "af26-trajectory-parent"),
            initialPose: RigidTransform(rotation: UnitQuaternion(axis: .unitZ, angle: 0.4), translation: Vector3(1, 2, 0)),
            rotationAxis: .unitZ, segments: segments, policy: policy, work: &work))
    }

    private static func jet(displacement: Double, rate: Double, acceleration: Double) throws -> PrescribedMotionJet {
        try PrescribedMotionJet(displacement: Vector3(0, 0.125*displacement, 0), angle: displacement,
            linearVelocity: Vector3(0, 0.125*rate, 0), angularRate: rate,
            linearAcceleration: Vector3(0, 0.125*acceleration, 0), angularAcceleration: acceleration)
    }

    @inline(never)
    private static func compile(program: PrescribedBaseTrajectoryProgram, planar: Bool, root: EntityID,
                                mass: Double, center: Vector3, inertia: Matrix3, child: EntityID?, childFrame: EntityID?,
                                joint: EntityID?, childMass: Double, childCenter: Vector3,
                                childInertia: Matrix3) throws -> CompiledMechanicalModel {
        var work = try GeometricProbeContext.work()
        let sample = try OriginalPrescribedBaseTrajectoryAcceptance.sealedBaseMotion(program, time: 0,
            policy: program.policy, sampler: AnalyticPrescribedBaseTrajectorySampler(), work: &work)
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 1e-12)
        let provenance = try SourceProvenance(source: "af26-trajectory-public-inertias", revision: 1)
        let pose = program.trajectory.initialPose, frame = program.trajectory.frame
        var bodies = [try body(id: root, frame: frame, mode: .prescribedKinematic, planar: planar,
            pose: pose, mass: mass, center: center, inertia: inertia, policy: inertiaPolicy, source: provenance)]
        var joints: [MechanicalJoint] = []
        var q = sample.q, v = sample.v, a = sample.a
        if let child, let childFrame, let joint {
            bodies.append(try body(id: child, frame: childFrame, mode: .dynamic, planar: planar,
                pose: pose, mass: childMass, center: childCenter, inertia: childInertia, policy: inertiaPolicy, source: provenance))
            let record = try JointRecord(id: joint, parentBody: root, childBody: child,
                parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "af26-prismatic-parent"), placement: .fixed(.identity)),
                childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "af26-prismatic-child"), placement: .fixed(.identity)),
                manifold: JointManifold(.prismatic(axis: .unitY)))
            joints.append(MechanicalJoint(record: record, authority: .dynamicState))
            // Context obtains the child's original force-consistent acceleration before Runtime admission.
            q.append(0); v.append(0); a.append(0)
        }
        let descriptor = try MechanicalDescriptor(identity: "af26-trajectory-" + (planar ? "planar-" : "spatial-") +
            (program.trajectory.segmentCount == 0 ? "harmonic" : "piecewise") + (child == nil ? "-root" : "-child"),
            revision: 1, bodies: bodies, joints: joints, root: root, rootBase: program.layout, rootAuthority: .prescribedMotion,
            worldFrame: program.trajectory.parentFrame, initialState: KinematicState(revision: 1, time: 0, q: q, v: v, acceleration: a),
            representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 2,
                maximumVelocities: 7, maximumJacobianScalars: 512),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 32, maximumIdentifierBytes: 8192, maximumSparsityEntries: 2048,
            maximumDependencyEntries: 2048, maximumExtensionRecords: 1, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
        return try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
    }

    @inline(never)
    private static func body(id: EntityID, frame: EntityID, mode: BodyMotionMode, planar: Bool, pose: RigidTransform,
                             mass: Double, center: Vector3, inertia: Matrix3, policy: InertiaValidationPolicy,
                             source: SourceProvenance) throws -> MechanicalBody {
        if planar {
            return .planar(try BodyRecord2D(id: id, frame: frame, mode: mode,
                bodyToWorld: PlanarPose(x: pose.translation.x, y: pose.translation.y, angle: 0.4),
                representations: BodyRepresentations(), inertia: InertialRepresentation2D(properties: MassProperties2D(
                    mass: mass, centerX: center.x, centerY: center.y, polarInertiaAtCenter: inertia.m22), provenance: source, quality: .exact)))
        }
        return .spatial(try BodyRecord3D(id: id, frame: frame, mode: mode, bodyToWorld: pose,
            representations: BodyRepresentations(), inertia: InertialRepresentation3D(properties: MassProperties3D(
                mass: mass, centerOfMass: center, inertiaAtCenter: inertia,
                policy: policy), provenance: source, quality: .exact)))
    }
}
