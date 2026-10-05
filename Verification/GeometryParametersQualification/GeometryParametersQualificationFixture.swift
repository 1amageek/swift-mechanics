import SwiftMechanics

public struct GeometryParametersQualificationFixture: Sendable {
    public let tree: KinematicTree
    public let state: KinematicState
    public let provenance: SourceProvenance
    public let specifications: [JointSpecification]

    public init(specifications: [JointSpecification]? = nil, rootBase: BaseLayout = .fixed,
                movingParent: Bool = false) throws {
        let chosen: [JointSpecification]
        if let specifications { chosen = specifications }
        else { chosen = [.revolute(axis: try Vector3(0, 0, 2)), .prismatic(axis: try Vector3(1, 2, -1)),
                         .screw(axis: try Vector3(2, -1, 3), pitchMetersPerRadian: 0.25)] }
        self.specifications = chosen
        provenance = try SourceProvenance(source: "geometry-parameters-independent-model", revision: 7)
        tree = try Self.build(chosen, rootBase: rootBase, movingParent: movingParent)
        if chosen.count == 3 && rootBase == .fixed {
            state = try KinematicState(revision: 7, time: 3, q: [0.4, 0.3, -0.2], v: [2, -0.7, 1.2], acceleration: [-0.6, 0.9, 1.1])
        } else {
            var q = [Double](repeating: 0, count: tree.layout.positionCount)
            if rootBase == .spatialFloating { q[3] = 1 }
            for (i, specification) in chosen.enumerated() {
                if case .spherical = specification { q[tree.layout.joints[i].positions.start] = 1 }
            }
            state = try KinematicState(revision: 7, time: 3, q: q,
                v: [Double](repeating: 0, count: tree.layout.velocityCount),
                acceleration: [Double](repeating: 0, count: tree.layout.velocityCount))
        }
    }

    public static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: "geometry-" + key) }
    public static func pose(_ index: Int) throws -> RigidTransform {
        try RigidTransform(rotation: UnitQuaternion(axis: Vector3(1, Double(index + 2), -1), angle: 0.17 * Double(index + 1)),
            translation: Vector3(0.3 + Double(index) * 0.11, -0.4 + Double(index) * 0.07, 0.2 - Double(index) * 0.05))
    }

    public static func build(_ specifications: [JointSpecification], rootBase: BaseLayout = .fixed,
                             movingParent: Bool = false, bindings: [GeometryParameterBinding] = [],
                             direction: [Double] = [], delta: Double = 0) throws -> KinematicTree {
        var root = try pose(0), parents: [RigidTransform] = [], children: [RigidTransform] = []
        var chosen = specifications
        for i in specifications.indices { parents.append(try pose(2*i + 1)); children.append(try pose(2*i + 2)) }
        for (i, binding) in bindings.enumerated() {
            let step = delta * direction[i]
            switch binding.target {
            case .fixedRoot: root = try perturb(root, chart: binding.chart, step: step)
            case .fixedAnchor(let joint, let frame):
                for j in specifications.indices where joint == (try id(.joint, "joint-\(j)")) {
                    if frame == (try id(.frame, "parent-\(j)")) { parents[j] = try perturb(parents[j], chart: binding.chart, step: step) }
                    else { children[j] = try perturb(children[j], chart: binding.chart, step: step) }
                }
            case .jointAxis(let joint, _):
                for j in specifications.indices where joint == (try id(.joint, "joint-\(j)")) {
                    guard case .normalizedAxis(let raw, let perUnit) = binding.chart else { throw GeometryParametersQualificationError.assertion("Axis oracle chart") }
                    let axis = try raw.adding(perUnit.scaled(by: step))
                    switch specifications[j] {
                    case .revolute: chosen[j] = .revolute(axis: axis)
                    case .prismatic: chosen[j] = .prismatic(axis: axis)
                    case .screw(_, let pitch): chosen[j] = .screw(axis: axis, pitchMetersPerRadian: pitch)
                    default: throw GeometryParametersQualificationError.assertion("Axis oracle scalar domain")
                    }
                }
            case .topology: throw GeometryParametersQualificationError.assertion("Topology oracle unavailable")
            }
        }
        var bodies: [KinematicBody] = [], joints: [JointRecord] = []
        for i in 0...chosen.count {
            let record = try BodyRecord3D(id: id(.body, "body-\(i)"), frame: id(.frame, "body-\(i)"),
                mode: i == 0 ? .static : .prescribedKinematic, bodyToWorld: i == 0 ? root : .identity,
                representations: BodyRepresentations(), inertia: nil)
            bodies.append(KinematicBody(body: record))
            if i > 0 {
                joints.append(try JointRecord(id: id(.joint, "joint-\(i - 1)"), parentBody: bodies[i - 1].id, childBody: bodies[i].id,
                    parentAnchor: JointAnchor(frame: id(.frame, "parent-\(i - 1)"), placement: movingParent && i == 1 ? .prescribed : .fixed(parents[i - 1])),
                    childAnchor: JointAnchor(frame: id(.frame, "child-\(i - 1)"), placement: .fixed(children[i - 1])),
                    manifold: JointManifold(chosen[i - 1])))
            }
        }
        return try KinematicTree(bodies: bodies, joints: joints, root: bodies[0].id, rootBase: rootBase,
            worldFrame: id(.frame, "world"), revision: 7,
            capacity: KinematicCapacity(maximumBodies: 6, maximumVelocities: 12, maximumJacobianScalars: 432))
    }

    private static func perturb(_ pose: RigidTransform, chart: GeometryParameterChart, step: Double) throws -> RigidTransform {
        switch chart {
        case .translation(_, let perMeter):
            return RigidTransform(rotation: pose.rotation, translation: try pose.translation.adding(perMeter.scaled(by: step)))
        case .rotation(_, let tangent):
            return RigidTransform(rotation: try pose.rotation.multiplied(by: UnitQuaternion(rotationVector: tangent.scaled(by: step))), translation: pose.translation)
        case .normalizedAxis: throw GeometryParametersQualificationError.assertion("Placement oracle chart")
        }
    }

    public func binding(_ id: UInt64, target: GeometryParameterTarget, chart: GeometryParameterChart,
                        revision: UInt64 = 7, provenance: SourceProvenance? = nil) throws -> GeometryParameterBinding {
        let original: SourceProvenance
        if let provenance { original = provenance } else { original = self.provenance }
        return try GeometryParameterBinding(parameterID: id, originalValue: 1.25, dimension: chart.dimension,
            modelSource: original, parameterSource: SourceProvenance(source: "geometry-parameter-\(id)-SI", revision: 2),
            treeRevision: revision, target: target, chart: chart)
    }
    public func source(_ bindings: [GeometryParameterBinding], state: KinematicState? = nil) -> GeometryParameterSource {
        let actual: KinematicState
        if let state { actual = state } else { actual = self.state }
        return GeometryParameterSource(modelSource: provenance, tree: tree, state: actual, bindings: bindings)
    }
    public static func jointPolicy(length: Double = 1) throws -> JointEvaluationPolicy {
        try JointEvaluationPolicy(quaternionTolerance: NumericalTolerance(absolute: 1e-12, relative: 1e-12),
            chartRankRelative: 1e-10, characteristicLengthMeters: length)
    }
    public static func policy(cancelled: @escaping @Sendable () -> Bool = { false }, length: Double = 1,
                              bodies: Int = 6, parameters: Int = 16) throws -> GeometryParameterPolicy {
        try GeometryParameterPolicy(maximumBodies: bodies, maximumVelocities: 12, maximumParameters: parameters,
            minimumRawAxisMagnitude: 1e-8, primalTolerance: NumericalTolerance(absolute: 1e-9, relative: 1e-10),
            residualTolerance: NumericalTolerance(absolute: 1e-9, relative: 1e-10), jointPolicy: jointPolicy(length: length), isCancelled: cancelled)
    }
    public static func work(operations: Int = 5_000_000, storage: Int = 1_000_000, seeded: Bool = false) throws -> NumericalWork {
        var work = NumericalWork(budget: try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: 3))
        if seeded { try work.chargeOperations(11); try work.requireStorage(17); try work.advanceIteration() }
        return work
    }
    public func product(_ bindings: [GeometryParameterBinding], direction: [Double]) throws -> GeometryParameterProduct {
        var work = try Self.work(), calls = try DerivativeSupplierWork(maximumCalls: 100)
        let supplier: any GeometryParameterDifferentiating = ExactGeometryParameterDifferentiator()
        return try supplier.direction(source(bindings), direction: direction, policy: Self.policy(), supplierWork: &calls, work: &work)
    }
}
