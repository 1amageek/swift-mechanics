import SwiftMechanics
#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("The verification profile must provide system scalar mathematics.")
#endif

struct FourBarProbeModel: Sendable {
    let model: CompiledMechanicalModel
    let crank: EntityID
    let coupler: EntityID
    let rocker: EntityID
    let crankJoint: EntityID
    let couplerJoint: EntityID
    let rockerJoint: EntityID
    let crankIndex: Int
    let couplerIndex: Int
    let rockerIndex: Int

    @inline(never)
    init() throws {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 1e-12)
        let source = try SourceProvenance(source: "four-bar-public-oracle", revision: 1)
        let root = try EntityID(kind: .body, key: "four-bar-ground")
        crank = try EntityID(kind: .body, key: "four-bar-crank")
        coupler = try EntityID(kind: .body, key: "four-bar-coupler")
        rocker = try EntityID(kind: .body, key: "four-bar-rocker")
        crankJoint = try EntityID(kind: .joint, key: "four-bar-input")
        couplerJoint = try EntityID(kind: .joint, key: "four-bar-coupler-hinge")
        rockerJoint = try EntityID(kind: .joint, key: "four-bar-output")
        let q1 = 0.5, bx = cos(q1), by = sin(q1), dx = 2-bx, dy = -by
        let separation = (dx*dx+dy*dy).squareRoot()
        let height = (4-0.25*separation*separation).squareRoot()
        let cx = 0.5*(bx+2)-height*dy/separation
        let cy = 0.5*by+height*dx/separation
        let couplerAngle = atan2(cy-by, cx-bx), rockerAngle = atan2(cy, cx-2)
        func body(_ id: EntityID, length: Double, pose: RigidTransform, mode: BodyMotionMode) throws -> MechanicalBody {
            let calculator: any MassPropertyCalculating = AnalyticMassCalculator()
            let box = try calculator.properties(of: .box(width: length, depth: 0.1, height: 0.1), density: 100, policy: inertiaPolicy)
            let inertia = try InertialRepresentation3D(properties: MassProperties3D(mass: box.mass,
                centerOfMass: Vector3(length/2, 0, 0), inertiaAtCenter: box.inertiaAtCenter, policy: inertiaPolicy),
                provenance: source, quality: .exact)
            return .spatial(try BodyRecord3D(id: id, frame: EntityID(kind: .frame, key: id.key+"-frame"),
                mode: mode, bodyToWorld: pose, representations: BodyRepresentations(), inertia: inertia))
        }
        let crankPose = try RigidTransform(rotation: UnitQuaternion(axis: .unitZ, angle: q1), translation: .zero)
        let couplerPose = try RigidTransform(rotation: UnitQuaternion(axis: .unitZ, angle: couplerAngle), translation: Vector3(bx, by, 0))
        let rockerPose = try RigidTransform(rotation: UnitQuaternion(axis: .unitZ, angle: rockerAngle), translation: Vector3(2, 0, 0))
        let bodies = try [body(root, length: 1, pose: .identity, mode: .static),
            body(crank, length: 1, pose: crankPose, mode: .dynamic),
            body(coupler, length: 2, pose: couplerPose, mode: .dynamic),
            body(rocker, length: 2, pose: rockerPose, mode: .dynamic)]
        func joint(_ id: EntityID, parent: EntityID, child: EntityID, offset: Vector3) throws -> MechanicalJoint {
            let record = try JointRecord(id: id, parentBody: parent, childBody: child,
                parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: id.key+"-parent"),
                    placement: .fixed(RigidTransform(rotation: .identity, translation: offset))),
                childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: id.key+"-child"), placement: .fixed(.identity)),
                manifold: JointManifold(.revolute(axis: .unitZ)))
            return MechanicalJoint(record: record, authority: .dynamicState)
        }
        let joints = try [joint(crankJoint, parent: root, child: crank, offset: .zero),
            joint(couplerJoint, parent: crank, child: coupler, offset: Vector3(1, 0, 0)),
            joint(rockerJoint, parent: root, child: rocker, offset: Vector3(2, 0, 0))]
        let capacity = try KinematicCapacity(maximumBodies: 4, maximumVelocities: 16, maximumJacobianScalars: 384)
        let world = try EntityID(kind: .frame, key: "four-bar-world")
        let proposed = try KinematicTree(bodies: bodies.map { try $0.kinematicBody() }, joints: joints.map { $0.record },
            root: root, rootBase: .fixed, worldFrame: world, revision: 1, capacity: capacity)
        func index(_ id: EntityID) throws -> Int {
            guard let entry = proposed.layout.joints.first(where: { $0.joint == id }),
                  entry.positions.count == 1, entry.velocities.count == 1,
                  entry.positions.start == entry.velocities.start else { throw FoundationVerificationError.analyticCheckFailed }
            return entry.positions.start
        }
        crankIndex = try index(crankJoint); couplerIndex = try index(couplerJoint); rockerIndex = try index(rockerJoint)
        var q = [Double](repeating: 0, count: proposed.layout.positionCount)
        q[crankIndex] = q1; q[couplerIndex] = couplerAngle-q1; q[rockerIndex] = rockerAngle
        let zero = [Double](repeating: 0, count: proposed.layout.velocityCount)
        let descriptor = try MechanicalDescriptor(identity: "four-bar-public", revision: 1,
            bodies: bodies, joints: joints, root: root, rootBase: .fixed, rootAuthority: .fixed, worldFrame: world,
            initialState: KinematicState(revision: 1, time: 0, q: q, v: zero, acceleration: zero),
            representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(kinematicCapacity: capacity,
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-9, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 64, maximumIdentifierBytes: 8192, maximumSparsityEntries: 4096,
            maximumDependencyEntries: 4096, maximumExtensionRecords: 1, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 1024, arithmeticOperations: 10000, iterations: 100),
            target: FoundationVerification.compilerVerificationTarget)
        model = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
        guard model.tree.layout == proposed.layout else { throw FoundationVerificationError.analyticCheckFailed }
    }

    func originalClosure(q: [Double]) -> [Double] {
        let a = q[crankIndex], b = a+q[couplerIndex], c = q[rockerIndex]
        return [cos(a)+2*cos(b)-2-2*cos(c), sin(a)+2*sin(b)-2*sin(c), 0]
    }

    func originalVelocity(q: [Double], v: [Double]) -> [Double] {
        let a = q[crankIndex], b = a+q[couplerIndex], c = q[rockerIndex]
        let u = v[crankIndex], w = u+v[couplerIndex], z = v[rockerIndex]
        return [-sin(a)*u-2*sin(b)*w+2*sin(c)*z, cos(a)*u+2*cos(b)*w-2*cos(c)*z, 0]
    }

    func originalAcceleration(q: [Double], v: [Double], acceleration: [Double]) -> [Double] {
        let a = q[crankIndex], b = a+q[couplerIndex], c = q[rockerIndex]
        let u = v[crankIndex], w = u+v[couplerIndex], z = v[rockerIndex]
        let ua = acceleration[crankIndex], wa = ua+acceleration[couplerIndex], za = acceleration[rockerIndex]
        return [-cos(a)*u*u-sin(a)*ua-2*cos(b)*w*w-2*sin(b)*wa+2*cos(c)*z*z+2*sin(c)*za,
            -sin(a)*u*u+cos(a)*ua-2*sin(b)*w*w+2*cos(b)*wa+2*sin(c)*z*z-2*cos(c)*za, 0]
    }

    func originalKineticEnergy(q: [Double], v: [Double]) -> Double {
        let a = q[crankIndex], b = a + q[couplerIndex]
        let u = v[crankIndex], w = u + v[couplerIndex], z = v[rockerIndex]
        let crankInertia = 1.01 / 12, longRodInertia = 8.02 / 12
        let couplerSpeedSquared = u * u + w * w + 2 * cos(a - b) * u * w
        return 0.5 * ((0.25 + crankInertia) * u * u + 2 * couplerSpeedSquared
            + longRodInertia * w * w + (2 + longRodInertia) * z * z)
    }
}
