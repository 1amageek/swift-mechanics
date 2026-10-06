import SwiftMechanics

public enum URDFQualificationCases {
    public static func rotatedInertiaAndMotion() throws {
        let result = try decode(URDFQualificationFixtures.robot())
        try check(result.model.tree.layout.positionCount == 1 && result.model.tree.layout.velocityCount == 1, "Original fixed/continuous layout")
        let arm = try body(result, "arm")
        guard let supplied = arm.inertia else { throw URDFQualificationError.assertion("Missing actual supplied inertia") }
        try scalar(supplied.properties.mass, 2, "SI mass")
        try vector(supplied.properties.centerOfMass, 1, 0, 0, "Original body COM")
        let inertia = supplied.properties.inertiaAtCenter
        try scalar(inertia.m00, 3, "Rotated Ixx"); try scalar(inertia.m11, 2, "Rotated Iyy"); try scalar(inertia.m22, 4, "Rotated Izz")
        try scalar(inertia.m01, -0.25, "Rotated signed Ixy"); try scalar(inertia.m02, -0.4, "Rotated signed Ixz"); try scalar(inertia.m12, 0.3, "Rotated signed Iyz")
        try check(supplied.provenance.revision == 7, "Original inertia source revision")
        let state = try moving(result, angle: .pi / 2, rate: 2, acceleration: 3)
        let snapshot = try result.model.evaluate(state)
        let armMotion = try snapshot.body(URDFQualificationFixtures.id(.body, "arm")).motion
        let payload = try snapshot.body(URDFQualificationFixtures.id(.body, "payload")).motion
        try vector(armMotion.pose.translation, 1, 0, 0, "Joint origin applied once")
        try vector(payload.pose.translation, 1, 2, 0, "Fixed child follows actual q")
        try vector(payload.velocity.linear, -4, 0, 0, "Original child velocity")
        try vector(payload.acceleration.linear, -6, -8, 0, "Original child tangential/centripetal acceleration")
        let unwrapped = try moving(result, angle: 2 * .pi + 0.25)
        try scalar(unwrapped.state.q[0], 2 * .pi + 0.25, "Continuous coordinate remains unwrapped")
    }

    public static func actualRigidEquations() throws {
        let result = try decode(URDFQualificationFixtures.robot())
        let state = try moving(result, angle: 0, rate: 2, acceleration: 3)
        let provider: any URDFMechanicalConfiguring = result
        var semantic = try URDFQualificationFixtures.work()
        let gravity = try AffineGravity(frame: URDFQualificationFixtures.id(.frame, "world"), accelerationAtOrigin: Vector3(0, -10, 0))
        let input = try provider.dynamicsInput(state: state, gravity: gravity, bodyWrenches: [], generalizedForces: [], work: &semantic)
        try check(input.inertias.count == 3, "Complete real snapshot inertia inventory")
        let kernel: any RigidEquationComputing = RigidEquationKernel()
        var loads = try URDFQualificationFixtures.loads(), numerical = try URDFQualificationFixtures.numerical()
        let system = try kernel.assemble(input, admission: URDFQualificationFixtures.dynamics(), loadWork: &loads, work: &numerical)
        try scalar(system.massMatrix[0], 11, "Independent pivot inertia 4+2*1^2+1+1*2^2")
        try scalar(system.inertialBias[0], 0, "One hinge scalar inertial bias")
        try scalar(system.forces.gravity[0], -40, "Independent gravity torque")
        try scalar(system.forces.actualPower, -80, "Gravity force power at actual rate")
        var original = [0.0]
        try kernel.originalInertialForce(system, acceleration: [3], includeBias: true, into: &original, work: &numerical)
        try scalar(original[0], 33, "Original inertial projection matches independent M*a")
        let energy = try kernel.energy(system, acceleration: [3], angularMomentumReference: .zero, requireComplete: true, work: &numerical)
        try scalar(energy.kineticEnergy, 22, "Independent 1/2 M v^2")
        try scalar(energy.kineticEnergyRate, 66, "Independent M*v*a")
        try vector(energy.linearMomentum, 0, 8, 0, "Original physical linear momentum")
        try vector(energy.angularMomentum, -0.8, 0.6, 30, "Off-diagonal spin and orbital angular momentum")
        let quarter = try moving(result, angle: .pi / 2)
        let quarterInput = try provider.dynamicsInput(state: quarter, gravity: gravity, bodyWrenches: [], generalizedForces: [], work: &semantic)
        let quarterSystem = try kernel.assemble(quarterInput, admission: URDFQualificationFixtures.dynamics(), loadWork: &loads, work: &numerical)
        try scalar(quarterSystem.gravityPotential, 40, "Independent m*g*height at moving COM")
        try scalar(quarterSystem.forces.gravity[0], 0, "Quarter-turn gravity torque")
    }

    public static func movingAnalyticCollision() throws {
        let result = try decode(URDFQualificationFixtures.robot())
        let state = try moving(result, angle: .pi / 2)
        var semantic = try URDFQualificationFixtures.work()
        guard let sphere = result.collisions.first(where: { $0.body.key == "arm" }),
              let box = result.collisions.first(where: { $0.body.key == "base" }) else {
            throw URDFQualificationError.assertion("Missing actual colliders")
        }
        let filter = ColliderFilter(enabled: true, layerBits: 1, maskBits: 1, isTrigger: false)
        let sphereProvider: any URDFCollisionConfiguring = sphere, boxProvider: any URDFCollisionConfiguring = box
        let first = try sphereProvider.proxy(state: state, model: result.model, frameRevision: 12, margin: 0, filter: filter, work: &semantic)
        let second = try boxProvider.proxy(state: state, model: result.model, frameRevision: 12, margin: 0, filter: filter, work: &semantic)
        try vector(first.pose.translation, 1, 3, 0, "Actual moving collider origin")
        var work = CollisionWork(budget: try CollisionBudget(scalarStorage: 1024, operations: 20_000, iterations: 128, records: 16))
        let geometry: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        let witness = try geometry.witness(first: first, second: second,
            policy: CollisionQueryPolicy(absoluteLengthTolerance: 1e-10, relativeLengthTolerance: 1e-10, referenceLength: 1, maximumApproximationError: 0), work: &work)
        try scalar(witness.separation, 1.75, "Independent sphere/box separation in metres")
        try vector(witness.pointA, 1, 2.75, 0, "Original sphere witness")
        try vector(witness.pointB, 1, 1, 0, "Original box witness")
        try vector(witness.normal, 0, -1, 0, "Original first-to-second normal")
        try scalar(witness.originalBalanceResidual, 0, "Original witness balance")
    }

    public static func rootVariantsAndUnavailableDynamics() throws {
        let pose = RigidTransform(rotation: try UnitQuaternion(axis: .unitZ, angle: .pi / 2), translation: try Vector3(10, -2, 3))
        let fixed = try decode(URDFQualificationFixtures.robot(), options: URDFQualificationFixtures.options(pose: pose))
        let snapshot = try fixed.model.evaluate(moving(fixed, angle: .pi / 2))
        try vector(snapshot.body(URDFQualificationFixtures.id(.body, "payload")).motion.pose.translation, 8, -1, 3, "Explicit rotated/shifted fixed root")
        let floating = try decode(URDFQualificationFixtures.robot(), options: URDFQualificationFixtures.options(floating: true, pose: pose))
        try check(floating.model.tree.layout.positionCount == 8 && floating.model.tree.layout.velocityCount == 7, "Floating q/v chart")
        var q = floating.model.descriptor.initialState.q
        try scalar(q[0], 10, "Floating SI X"); try scalar(q[1], -2, "Floating SI Y"); try scalar(q[2], 3, "Floating SI Z")
        q[7] = 0
        let state = try floating.model.makeState(KinematicState(revision: 7, time: 2, q: q, v: [2, 0, 0, 0, 0, 0, 0], acceleration: [0, 0, 0, 0, 0, 0, 0]))
        var work = try URDFQualificationFixtures.work()
        let input = try floating.dynamicsInput(state: state, gravity: nil, bodyWrenches: [], generalizedForces: [], work: &work)
        let equations: any RigidEquationComputing = RigidEquationKernel()
        var loads = try URDFQualificationFixtures.loads(), numerical = try URDFQualificationFixtures.numerical()
        let system = try equations.assemble(input, admission: URDFQualificationFixtures.dynamics(), loadWork: &loads, work: &numerical)
        try scalar(system.massMatrix[0], 6, "Independent total floating translational mass")
        let missing = try decode(URDFQualificationFixtures.robot(rootInertia: false))
        let missingState = try missing.model.makeState(missing.model.descriptor.initialState)
        try expect("Missing static inertia refuses dynamics", matches: unsupported) { () throws(URDFFailure) in
            _ = try missing.dynamicsInput(state: missingState, gravity: nil, bodyWrenches: [], generalizedForces: [], work: &work)
        }
        let zero = try decode(URDFQualificationFixtures.minimal(link: URDFQualificationFixtures.unitInertia()))
        let zeroState = try zero.model.makeState(zero.model.descriptor.initialState)
        try expect("V0 provider explicitly refuses", matches: unsupported) { () throws(URDFFailure) in
            _ = try zero.dynamicsInput(state: zeroState, gravity: nil, bodyWrenches: [], generalizedForces: [], work: &work)
        }
    }

    public static func originalExportAndLosses() throws {
        let codec: any URDFDocumentCoding = URDFQualificationFixtures.codec()
        let result = try decode(URDFQualificationFixtures.original, options: URDFQualificationFixtures.options(losses: true))
        try check(result.losses.count == 2, "Explicit unknown attribute/element losses")
        var work = try URDFQualificationFixtures.work()
        let bytes = try codec.encode(result: result, work: &work)
        try check(bytes == Array(URDFQualificationFixtures.canonical.utf8), "Independent literal original canonical bytes")
        let robot = try decode(URDFQualificationFixtures.robot())
        let original = try codec.encode(result: robot, work: &work)
        _ = try robot.model.evaluate(moving(robot, angle: 0.75, rate: 2))
        try check(try codec.encode(result: robot, work: &work) == original, "Moving state cannot alter original admitted export")
        let rebuilt = try decode(String(decoding: original, as: UTF8.self))
        guard let rebuiltInertia = try body(rebuilt, "arm").inertia else { throw URDFQualificationError.assertion("Export lost original inertia") }
        try scalar(rebuiltInertia.properties.inertiaAtCenter.m02, -0.4, "Export retains original rotated tensor")
        let mesh = try decode(URDFQualificationFixtures.minimal(link: URDFQualificationFixtures.mesh),
            options: URDFQualificationFixtures.options(losses: true, assets: true))
        try check(mesh.assets.count == 1 && mesh.assets[0].base == "caller-catalog" && mesh.assets[0].relativePath == "shapes/arm.stl", "Opaque unresolved asset retention")
        try check(mesh.collisions.isEmpty && mesh.losses.count == 2, "Visual and unresolved asset have explicit losses")
    }

    public static func semanticRefusals() throws {
        for (xml, label) in [
            ("<robot>", "Malformed XML"),
            ("<robot name='r' version='1.1'><link name='base'/></robot>", "Version"),
            ("<robot name='r' units='cm'><link name='base'/></robot>", "Unit declaration"),
            (URDFQualificationFixtures.minimal(robot: "<link name='base'/>"), "Duplicate link"),
            (URDFQualificationFixtures.minimal(robot: "<link name='other'/>"), "Disconnected root"),
            (URDFQualificationFixtures.robot(axis: "0 0 0"), "Zero axis"),
            (URDFQualificationFixtures.robot(axis: "0 0 1 2"), "Four-component axis"),
            (URDFQualificationFixtures.minimal(link: "<inertial><mass value='0'/><inertia ixx='1' ixy='0' ixz='0' iyy='1' iyz='0' izz='1'/></inertial>"), "Zero mass"),
            (URDFQualificationFixtures.minimal(link: "<inertial><mass value='1e-999'/><inertia ixx='1' ixy='0' ixz='0' iyy='1' iyz='0' izz='1'/></inertial>"), "Nonzero underflow"),
            (URDFQualificationFixtures.minimal(link: "<collision><geometry><sphere radius='NaN'/></geometry></collision>"), "Nonfinite lexical number"),
            (URDFQualificationFixtures.minimal(link: "<collision><geometry><sphere radius='0x1'/></geometry></collision>"), "Hex number"),
            (URDFQualificationFixtures.minimal(robot: "<joint name='spin' type='revolute'/>"), "Bounded joint"),
            (URDFQualificationFixtures.minimal(robot: "<mimic joint='spin'/>"), "Mimic law"),
            (URDFQualificationFixtures.minimal(robot: "<transmission name='drive'/>"), "Transmission law"),
            (URDFQualificationFixtures.minimal(robot: "<limit lower='0' upper='1'/>"), "Limit law"),
            (URDFQualificationFixtures.minimal(link: "<visual><geometry><mesh filename='../unsafe.stl'/></geometry></visual>"), "Unsafe asset")
        ] {
            try refused(xml, label, options: URDFQualificationFixtures.options(losses: true, assets: true))
        }
        try refused(URDFQualificationFixtures.robot(movingInertia: false), "Missing moving inertia")
        try refused(URDFQualificationFixtures.robot(damping: true), "Nonzero dynamics")
        try refused(URDFQualificationFixtures.minimal(link: URDFQualificationFixtures.mesh), "Strict visual loss")
        let first = try decode(URDFQualificationFixtures.robot())
        let second = try decode(URDFQualificationFixtures.robot(), options: URDFImportOptions(identity: "another", provenance: try SourceProvenance(source: "authored-urdf", revision: 7), worldFrame: URDFQualificationFixtures.id(.frame, "world"), rootName: "base", rootPlacement: .fixed(.identity), units: .metresKilogramsSecondsRadians, lossMode: .prohibit, assetBase: nil))
        var work = try URDFQualificationFixtures.work()
        let foreignState = try second.model.makeState(second.model.descriptor.initialState)
        try expect("Foreign state refuses actual collision", matches: compilationFailure) { () throws(URDFFailure) in
            _ = try first.collisions[0].proxy(state: foreignState, model: first.model,
                frameRevision: 0, margin: 0, filter: ColliderFilter(enabled: true, layerBits: 1, maskBits: 1, isTrigger: false), work: &work)
        }
    }

    public static func capacitiesAndReceipts() throws {
        let codec: any URDFDocumentCoding = URDFQualificationFixtures.codec(), xml = URDFQualificationFixtures.robot()
        let options = try URDFQualificationFixtures.options(), compilation = try URDFQualificationFixtures.compilation()
        let assetOptions = try URDFQualificationFixtures.options(losses: true, assets: true)
        for work in [try URDFQualificationFixtures.work(links: 0), try URDFQualificationFixtures.work(joints: 0),
                     try URDFQualificationFixtures.work(geometries: 0), try URDFQualificationFixtures.work(identifier: 0),
                     try URDFQualificationFixtures.work(operations: 0), try URDFQualificationFixtures.work(storage: 0),
                     try URDFQualificationFixtures.work(xmlInput: 0), try URDFQualificationFixtures.work(xmlNodes: 0)] {
            var bounded = work
            try expect("Actual zero semantic/XML budget", matches: resourceFailure) { () throws(URDFFailure) in
                _ = try codec.decode(bytes: Array(xml.utf8), options: options, compilationPolicy: compilation, work: &bounded)
            }
        }
        for work in [try URDFQualificationFixtures.work(assets: 0), try URDFQualificationFixtures.work(losses: 0), try URDFQualificationFixtures.work(reference: 0)] {
            var bounded = work
            try expect("Actual asset/loss/reference budget", matches: resourceFailure) { () throws(URDFFailure) in
                _ = try codec.decode(bytes: Array(URDFQualificationFixtures.minimal(link: URDFQualificationFixtures.mesh).utf8), options: assetOptions, compilationPolicy: compilation, work: &bounded)
            }
        }
        var semantic = try URDFQualificationFixtures.work(storage: 0)
        try expect("Semantic failure retains actual XML consumption", matches: resourceFailure) { () throws(URDFFailure) in
            _ = try codec.decode(bytes: Array(xml.utf8), options: options, compilationPolicy: compilation, work: &semantic)
        }
        try check(semantic.operations > 0 && semantic.xml.operations > 0 && semantic.storageBytes == 0, "Accepted work retained, rejected storage not committed")
        var work = try URDFQualificationFixtures.work()
        let result = try codec.decode(bytes: Array(xml.utf8), options: URDFQualificationFixtures.options(), compilationPolicy: URDFQualificationFixtures.compilation(), work: &work)
        let before = work.operations
        _ = try codec.decode(bytes: Array(xml.utf8), options: URDFQualificationFixtures.options(), compilationPolicy: URDFQualificationFixtures.compilation(), work: &work)
        try check(work.operations > before, "Cumulative semantic ledger")
        var output = try URDFQualificationFixtures.work(xmlOutput: 0)
        try expect("Export output budget", matches: resourceFailure) { () throws(URDFFailure) in _ = try codec.encode(result: result, work: &output) }
        var compiler = try URDFQualificationFixtures.work()
        let limitedCompilation = try URDFQualificationFixtures.compilation(records: 0)
        try expect("Actual compiler record capacity", matches: compilationFailure) { () throws(URDFFailure) in
            _ = try codec.decode(bytes: Array(xml.utf8), options: options, compilationPolicy: limitedCompilation, work: &compiler)
        }
    }

    public static func cancellationResult() throws -> URDFImportResult { try decode(URDFQualificationFixtures.robot()) }
    public static func cancelledTask(_ result: URDFImportResult, state: CompiledKinematicState) throws {
        try check(Task.isCancelled, "Actually cancelled Native Task")
        let codec: any URDFDocumentCoding = URDFQualificationFixtures.codec()
        let options = try URDFQualificationFixtures.options(), compilation = try URDFQualificationFixtures.compilation()
        var work = try URDFQualificationFixtures.work()
        try expect("Cancelled decode", matches: cancelled) { () throws(URDFFailure) in
            _ = try codec.decode(bytes: Array(URDFQualificationFixtures.robot().utf8), options: options, compilationPolicy: compilation, work: &work)
        }
        try expect("Cancelled original export", matches: cancelled) { () throws(URDFFailure) in _ = try codec.encode(result: result, work: &work) }
        try expect("Cancelled dynamics provider", matches: cancelled) { () throws(URDFFailure) in
            _ = try result.dynamicsInput(state: state, gravity: nil, bodyWrenches: [], generalizedForces: [], work: &work)
        }
        try expect("Cancelled collision provider", matches: cancelled) { () throws(URDFFailure) in
            _ = try result.collisions[0].proxy(state: state, model: result.model, frameRevision: 0, margin: 0,
                filter: ColliderFilter(enabled: true, layerBits: 1, maskBits: 1, isTrigger: false), work: &work)
        }
        try check(work.operations == 0 && work.storageBytes == 0, "Cancelled operations publish no charged progress")
    }

    private static func decode(_ xml: String, options: URDFImportOptions? = nil) throws -> URDFImportResult {
        var work = try URDFQualificationFixtures.work()
        let codec: any URDFDocumentCoding = URDFQualificationFixtures.codec()
        return try codec.decode(bytes: Array(xml.utf8), options: options ?? URDFQualificationFixtures.options(), compilationPolicy: URDFQualificationFixtures.compilation(), work: &work)
    }
    private static func moving(_ result: URDFImportResult, angle: Double, rate: Double = 0, acceleration: Double = 0) throws -> CompiledKinematicState {
        try result.model.makeState(KinematicState(revision: 7, time: 2, q: [angle], v: [rate], acceleration: [acceleration]))
    }
    private static func body(_ result: URDFImportResult, _ name: String) throws -> BodyRecord3D {
        for entry in result.model.descriptor.bodies { if entry.id.key == name, case .spatial(let body) = entry { return body } }
        throw URDFQualificationError.assertion("Missing actual body " + name)
    }
    private static func refused(_ xml: String, _ label: String, options: URDFImportOptions? = nil) throws {
        var work = try URDFQualificationFixtures.work()
        let selected = try options ?? URDFQualificationFixtures.options(), compilation = try URDFQualificationFixtures.compilation()
        let codec: any URDFDocumentCoding = URDFQualificationFixtures.codec()
        try expect(label, matches: { failure in
            switch failure.reason { case .invalid, .duplicate, .unsupported, .missing, .xml, .core, .model, .joint: return true; default: return false }
        }) { () throws(URDFFailure) in _ = try codec.decode(bytes: Array(xml.utf8), options: selected, compilationPolicy: compilation, work: &work) }
    }
    private static func expect(_ label: String, matches: (URDFFailure) -> Bool, operation: () throws(URDFFailure) -> Void) throws {
        do throws(URDFFailure) { try operation() }
        catch { try check(matches(error), label + ": wrong typed failure"); return }
        throw URDFQualificationError.assertion(label + ": unexpected successful publication")
    }
    private static func unsupported(_ failure: URDFFailure) -> Bool { if case .unsupported = failure.reason { return true }; return false }
    private static func compilationFailure(_ failure: URDFFailure) -> Bool { if case .compilation = failure.reason { return true }; return false }
    private static func resourceFailure(_ failure: URDFFailure) -> Bool {
        if case .limit = failure.reason { return true }
        if case .xml(let xml) = failure.reason, case .limit = xml.reason { return true }
        return false
    }
    private static func cancelled(_ failure: URDFFailure) -> Bool { if case .cancelled = failure.reason { return true }; return false }
    private static func scalar(_ actual: Double, _ expected: Double, _ label: String) throws {
        try check(actual.isFinite && abs(actual - expected) <= 2e-10 + abs(expected) * 1e-11, label)
    }
    private static func vector(_ actual: Vector3, _ x: Double, _ y: Double, _ z: Double, _ label: String) throws {
        try scalar(actual.x, x, label + " X"); try scalar(actual.y, y, label + " Y"); try scalar(actual.z, z, label + " Z")
    }
    private static func check(_ condition: Bool, _ label: String) throws { if !condition { throw URDFQualificationError.assertion(label) } }
}
