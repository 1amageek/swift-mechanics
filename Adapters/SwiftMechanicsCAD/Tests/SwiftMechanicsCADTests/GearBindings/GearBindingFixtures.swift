import Foundation
import CADCore
import CADGeometry
import CADIR
import CADModeling
import CADKernel
import SwiftMechanics
import SwiftMechanicsCAD

@available(macOS 15, *)
struct GearBindingFixtures {
    let document: CADDocument
    let geometry: CADGeometryAdmission
    let model: CompiledMechanicalModel
    let state: CompiledKinematicState
    let layout: ConstraintCoordinateLayout
    let first: CADGearShaftRequest
    let second: CADGearShaftRequest

    static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: key) }
    static func work() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 1_000_000,
            arithmeticOperations: 20_000_000, iterations: 100_000))
    }
    static func policy(records: Int = 100, metadata: Int = 4096) throws -> CADGearBindingPolicy {
        try CADGearBindingPolicy(lengthTolerance: 1e-8, directionTolerance: 1e-8,
            moduleTolerance: 1e-10, pressureRatioTolerance: 1e-10,
            maximumModelRecords: records, maximumMetadataBytes: metadata)
    }
    static func transmissionPolicy() throws -> TransmissionPolicy {
        try TransmissionPolicy(maximumCoordinates: 8, maximumPorts: 8, maximumRelations: 8,
            expectedLayoutRevision: 1, expectedModelRevision: 1, geometryTolerance: 1e-10,
            originalTolerance: 1e-8, powerScale: 1, powerTolerance: 1e-8)
    }
    static func source(secondRadius: Double = 0.04, twist: Double = 0,
                       repeated: Bool = false, parameters: Bool = false) throws -> CADDocument {
        var document = CADDocument(units: .millimeters)
        var features: [FeatureNode] = []
        for (i, teeth) in (repeated ? [20] : [20, 40]).enumerated() {
            let radius = i == 0 ? 0.02 : secondRadius, scale = radius / 0.032
            var dimensions: [InvoluteGearFeature.Dimension: CADExpression] = [
                .baseRadius: .constant(.length(radius * cos(.pi / 9) * 1000, unit: .millimeter)),
                .pitchRadius: .constant(.length(radius * 1000, unit: .millimeter)),
                .tipRadius: .constant(.length(0.034 * scale * 1000, unit: .millimeter)),
                .rootRadius: .constant(.length(0.0295 * scale * 1000, unit: .millimeter)),
                .filletRadius: .constant(.length(0.00064 * scale * 1000, unit: .millimeter)),
                .pitchToothAngle: .constant(.angle(180 / Double(teeth), unit: .degree)),
                .width: .constant(.length(10, unit: .millimeter)),
                .twistAngle: .constant(.angle(twist * 180 / .pi, unit: .degree)),
                .profileError: .constant(.length(0.0001, unit: .millimeter)),
                .sweepError: .constant(.length(0.001, unit: .millimeter))]
            if parameters {
                let parameter = Parameter(name: "pitch" + String(i), expression: dimensions[.pitchRadius]!, kind: .length)
                document.parameters.parameters[parameter.id] = parameter
                dimensions[.pitchRadius] = .reference(parameter.id)
            }
            let gear = InvoluteGearFeature(toothCount: teeth, dimensions: dimensions, doubleHelical: false)
            let node = try FeatureNodeFactory.make(operation: .involuteGear(gear), in: document,
                tolerance: CADFixtures.tolerance)
            features.append(node)
            document.designGraph.nodes[node.id] = node
            document.designGraph.order.append(node.id)
        }
        return document
    }
    init(document supplied: CADDocument? = nil, nonidentity: Bool = false,
         spacing: Double = 0.06, q: [Double] = [0, 0], v: [Double] = [2, -1],
         secondAxis: Vector3 = .unitZ, repeated: Bool = false) throws {
        document = try supplied ?? Self.source(repeated: repeated)
        let tol = try NumericalTolerance(absolute: 1e-11, relative: 1e-11)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tol, physicalityRelative: 0)
        let rootPose = RigidTransform(rotation: nonidentity ? try UnitQuaternion(axis: .unitX, angle: 0.4) : .identity,
            translation: nonidentity ? try Vector3(1, 2, 3) : .zero)
        var bodies: [MechanicalBody] = [], joints: [MechanicalJoint] = []
        var placements: [RigidTransform] = []
        let childAngles = nonidentity ? [0.07, -0.11] : [0.0, 0.0]
        for i in 0..<3 {
            let key = ["root", "first", "second"][i], inertia = [1.0, 2.0, 3.0][i]
            let properties = try MassProperties3D(mass: 1, centerOfMass: .zero,
                inertiaAtCenter: Matrix3(inertia, 0, 0, 0, inertia, 0, 0, 0, inertia), policy: inertiaPolicy)
            let pose: RigidTransform
            if i == 0 { pose = rootPose } else {
                let parent = RigidTransform(rotation: nonidentity ? try UnitQuaternion(axis: .unitZ, angle: i == 1 ? 0.13 : -0.21) : .identity,
                    translation: try Vector3(i == 1 ? 0 : spacing, 0, 0))
                let child = RigidTransform(rotation: try UnitQuaternion(axis: .unitZ, angle: childAngles[i-1]), translation: .zero)
                let axis = i == 1 ? Vector3.unitZ : secondAxis
                pose = try rootPose.composed(with: parent).composed(with:
                    RigidTransform(rotation: UnitQuaternion(axis: axis, angle: q[i-1]), translation: .zero)).composed(with: child.inverted())
                let record = try JointRecord(id: Self.id(.joint, key), parentBody: Self.id(.body, "root"), childBody: Self.id(.body, key),
                    parentAnchor: JointAnchor(frame: Self.id(.frame, key + "-parent"), placement: .fixed(parent)),
                    childAnchor: JointAnchor(frame: Self.id(.frame, key + "-child"), placement: .fixed(child)),
                    manifold: JointManifold(.revolute(axis: axis)))
                joints.append(MechanicalJoint(record: record, authority: .dynamicState))
                placements.append(pose)
            }
            bodies.append(.spatial(try BodyRecord3D(id: Self.id(.body, key), frame: Self.id(.frame, key + "-frame"),
                mode: i == 0 ? .static : .dynamic, bodyToWorld: pose, representations: BodyRepresentations(),
                inertia: InertialRepresentation3D(properties: properties,
                    provenance: SourceProvenance(source: "caller-supplied-rotor-inertia", revision: 1), quality: .exact))))
        }
        let initial = try KinematicState(revision: 1, time: 0, q: q, v: v, acceleration: [0, 0])
        let descriptor = try MechanicalDescriptor(identity: "cad-gears", revision: 1, bodies: bodies, joints: joints,
            root: Self.id(.body, "root"), rootBase: .fixed, rootAuthority: .fixed, worldFrame: Self.id(.frame, "world"),
            initialState: initial, representationRequirements: [], features: [], extensions: [])
        let compilation = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 8, maximumVelocities: 8, maximumJacobianScalars: 1000),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tol, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tol, rotationTolerance: tol, maximumRecords: 100,
            maximumIdentifierBytes: 10000, maximumSparsityEntries: 1000, maximumDependencyEntries: 1000,
            maximumExtensionRecords: 8, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10), target: .nativeCPU)
        model = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: compilation)
        state = try model.makeState(initial)
        layout = try ConstraintCoordinateLayout(coordinateIDs: [10, 20], dimensions: [.angle, .angle],
            scales: [2, 3], timeScale: 5, revision: 1)
        var requests: [CADOccurrenceRequest] = []
        for i in 0..<2 {
            let key = ["first", "second"][i]
            requests.append(CADOccurrenceRequest(id: key, sourceFeature: document.designGraph.order[repeated ? 0 : i],
                body: try Self.id(.body, key), frame: try Self.id(.frame, key + "-frame"),
                placement: placements[i], material: CADFixtures.material()))
        }
        geometry = try CADFixtures.admit(document, requests: requests)
        let a = try Self.endFace(geometry, "first"), b = try Self.endFace(geometry, "second")
        first = try CADGearShaftRequest(occurrenceID: "first", joint: Self.id(.joint, "first"), endFace: a, mountingPhase: -childAngles[0])
        second = try CADGearShaftRequest(occurrenceID: "second", joint: Self.id(.joint, "second"), endFace: b, mountingPhase: -childAngles[1])
    }
    static func endFace(_ geometry: CADGeometryAdmission, _ occurrence: String) throws -> CADAnchorReference {
        var work = try CADAdapterWork(maximumVisits: 2_000_000)
        for anchor in try geometry.anchors(occurrenceID: occurrence, expected: geometry.identity, work: &work) {
            guard case .face = anchor.topology else { continue }
            let query = try geometry.surfaceAnchor(anchor, nearestTo: .zero, expected: geometry.identity,
                options: SurfaceProjectionOptions(), work: &work)
            if abs(query.localOutwardNormal.z) > 0.999, abs(query.localPoint.x) < 1e-8,
                abs(query.localPoint.y) < 1e-8 { return anchor }
        }
        throw CADFixtures.FixtureFailure.missingAnchor
    }
    func request(source: CADSourceIdentity? = nil, first: CADGearShaftRequest? = nil,
                 second: CADGearShaftRequest? = nil, phase: Double = 0,
                 fidelity: CADGearFidelity = .idealExternalSpur) throws -> CADGearPairRequest {
        try CADGearPairRequest(freshSource: source ?? geometry.identity, model: model.stamp,
            first: first ?? self.first, second: second ?? self.second, phase: phase, phaseScale: 7,
            networkID: 11, relationID: 41, minimumPosition: [-100, -100], maximumPosition: [100, 100],
            minimumTime: 0, maximumTime: 10, fidelity: fidelity)
    }
    func bind(_ request: CADGearPairRequest? = nil, policy: CADGearBindingPolicy? = nil) throws -> CADGearPairBinding {
        var work = try CADAdapterWork(maximumVisits: 2_000_000), numerical = try Self.work()
        let producer: any CADGearBindingPreparing = ReferenceCADGearBindingPreparer()
        return try producer.bind(request ?? self.request(), geometry: geometry, model: model, state: state,
            layout: layout, policy: policy ?? Self.policy(), transmissionPolicy: Self.transmissionPolicy(),
            work: &work, transmissionWork: &numerical)
    }
    static func refuses(_ operation: () throws -> Void, matching: (CADGearBindingError) -> Bool) -> Bool {
        do { try operation(); return false }
        catch let error as CADGearBindingError { return matching(error) }
        catch { return false }
    }
    static func solvePolicy() throws -> MechanismSolvePolicy {
        let tolerance = try LinearTolerance<Double>(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-13)
        let nonlinear = try NonlinearPolicy<Double>(strategy: .lineSearch(contraction: 0.5, sufficientDecrease: 1e-4, minimumFraction: 1e-7),
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU), tolerance: tolerance,
            referenceScale: 1, minimumDirectionNorm: 0, derivativeProbeDistance: 1e-6,
            derivativeAbsoluteTolerance: 1e-4, derivativeRelativeTolerance: 1e-4,
            maximumFactorEntries: 1000, estimateCondition: false, budget: work().budget)
        let constraints = try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 8, maximumRows: 8, expectedLayoutRevision: 1),
            diagonalMetric: [1, 1], energyScale: 7, rankPolicy: .allowRedundancy, rankRelativeTolerance: 1e-10,
            originalResidualTolerance: 1e-8, maximumCorrection: 100, nonlinear: nonlinear,
            linearCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky), linearTolerance: tolerance)
        return try MechanismSolvePolicy(dynamics: DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            linearTolerance: tolerance, coordinateScales: [2, 3], energyScale: 7, timeScale: 5), constraints: constraints,
            maximumCoordinates: 8, maximumRows: 8, originalTolerance: 1e-8)
    }
    func system() throws -> RigidDynamicsSystem {
        var inertias: [RigidBodyInertia] = []
        for body in model.initialSnapshot.bodies {
            guard let record = model.descriptor.bodies.first(where: { $0.id == body.body }),
                  case .spatial(let source) = record, let inertia = source.inertia else { throw CADFixtures.FixtureFailure.missingFeature }
            inertias.append(try RigidBodyInertia(body: source.id, frame: source.frame, properties: inertia.properties))
        }
        let admission = DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 8, maximumVelocities: 8, maximumBodyWrenches: 8, maximumGeneralizedContributions: 8),
            angularVelocityTolerance: try NumericalTolerance(absolute: 1e-10, relative: 1e-10),
            linearVelocityTolerance: try NumericalTolerance(absolute: 1e-10, relative: 1e-10))
        var work = try Self.work(), load = LoadWork(budget: try LoadBudget(maximumWork: 0, maximumScalars: 0))
        return try RigidEquationKernel().assemble(RigidDynamicsInput(snapshot: model.evaluate(state), velocity: state.state.v,
            inertias: inertias, gravity: nil), admission: admission, loadWork: &load, work: &work)
    }
}
