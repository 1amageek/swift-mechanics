/// Mutable lowering workspace owned by one definition call.
public struct MachineDefinitionContext: Sendable {
    public let policy: MachineDefinitionPolicy
    internal private(set) var bodies: [MechanicalBody] = []
    internal private(set) var joints: [MechanicalJoint] = []
    private var identities: Set<EntityID> = []
    private var instances: Set<String> = []
    private var scopes: [String] = []
    private var scope = ""
    private var nodes = 0
    private var depth = 0
    private var iterations = 0
    private var identifierBytes = 0
    private static var reservedPrefix: String { "!machine:" }

    // AF34 structural drafts are call-local and use existing record types only.
    // Source-written state is not behavioral qualification of this added path.
    internal var structuralEnabled = false
    internal var structuralJointPolicy: JointEvaluationPolicy?
    internal var structuralBody: EntityID?
    internal var structuralBodyToWorld: RigidTransform?
    internal var structuralPlacement = RigidTransform.identity
    internal var structuralChildToWorld: RigidTransform?
    internal var structuralChild: EntityID?
    internal var structuralChildCount = 0
    internal var structuralRegisteredBodyCount = 0
    internal var structuralCoordinates: [EntityID: BaseCoordinates] = [:]
    internal var structuralAccelerations: [EntityID: [Double]] = [:]
    internal private(set) var structuralPendingJoints: Set<EntityID> = []
    internal var structuralGearDrafts: [(id: EntityID, rowID: UInt64, first: EntityID, second: EntityID,
        firstTeeth: UInt32, secondTeeth: UInt32, phase: Double, phaseScale: Double, internalMesh: Bool)] = []
    internal var structuralPassiveDrafts: [(id: EntityID, termID: UInt64, joint: EntityID, law: PolynomialSpringDamper)] = []
    internal var structuralMotorDrafts: [(id: EntityID, joint: EntityID, torqueNm: Double)] = []

    public init(policy: MachineDefinitionPolicy) { self.policy = policy }

    public mutating func lower<Content: Machine>(_ content: Content) throws(MachineDefinitionFailure) {
        guard nodes < policy.maximumNodes else { throw .capacityExceeded }
        guard depth < policy.maximumDepth else { throw .depthExceeded }
        nodes += 1; depth += 1
        defer { depth -= 1 }
        try content._makeDefinition(into: &self)
    }

    /// Returns an absolute identity suitable for root metadata or explicit external references.
    public static func scopedIdentity(_ id: EntityID, namespace: [String]) throws(MachineDefinitionFailure) -> EntityID {
        guard !id.key.hasPrefix(reservedPrefix) else { throw .reservedIdentity(id) }
        guard namespace.allSatisfy({ !$0.isEmpty }) else { throw .invalidNamespace }
        if namespace.isEmpty { return id }
        let path = namespace.map { String($0.count) + ":" + $0 }.joined()
        do { return try EntityID(kind: id.kind, key: reservedPrefix + path + String(id.key.count) + ":" + id.key) }
        catch { throw .invalidBody(error) }
    }

    public func resolve(_ reference: MachineEntityReference) throws(MachineDefinitionFailure) -> EntityID {
        switch reference {
        case .absolute(let id): return id
        case .local(let id): return try local(id)
        }
    }

    private func local(_ id: EntityID) throws(MachineDefinitionFailure) -> EntityID {
        guard !id.key.hasPrefix(Self.reservedPrefix) else { throw .reservedIdentity(id) }
        if scope.isEmpty { return id }
        let suffix = String(id.key.count) + ":" + id.key
        let bytes = Self.reservedPrefix.utf8.count + scope.utf8.count
        guard bytes <= policy.maximumIdentifierBytes,
              suffix.utf8.count <= policy.maximumIdentifierBytes - bytes else { throw .capacityExceeded }
        do { return try EntityID(kind: id.kind, key: Self.reservedPrefix + scope + suffix) }
        catch { throw .invalidBody(error) }
    }

    internal mutating func enterInstance(_ id: String) throws(MachineDefinitionFailure) {
        guard !id.isEmpty else { throw .invalidNamespace }
        guard scopes.count < policy.maximumDepth else { throw .depthExceeded }
        let segment = String(id.count) + ":" + id
        guard segment.utf8.count <= policy.maximumIdentifierBytes - identifierBytes,
              scope.utf8.count <= policy.maximumIdentifierBytes - identifierBytes - segment.utf8.count else { throw .capacityExceeded }
        let next = scope + segment
        guard !instances.contains(next) else { throw .duplicateInstance(next) }
        // Instance paths consume an identity slot even if their content is empty.
        guard instances.count < policy.maximumRecords - identities.count else { throw .capacityExceeded }
        identifierBytes += next.utf8.count
        instances.insert(next); scopes.append(scope); scope = next
    }

    internal mutating func leaveInstance() { scope = scopes.removeLast() }

    internal mutating func admitIteration() throws(MachineDefinitionFailure) {
        guard iterations < policy.maximumIterations, nodes < policy.maximumNodes,
              depth < policy.maximumDepth, instances.count < policy.maximumRecords - identities.count else { throw .capacityExceeded }
        iterations += 1
    }

    internal mutating func reserveWorld(_ id: EntityID) throws(MachineDefinitionFailure) {
        guard id.kind == .frame else { throw .invalidBody(.identityKindMismatch) }
        guard !id.key.hasPrefix(Self.reservedPrefix) else { throw .reservedIdentity(id) }
        try admit([id])
    }

    private mutating func admit(_ definitions: [EntityID], references: [EntityID] = []) throws(MachineDefinitionFailure) {
        guard definitions.count <= policy.maximumRecords - identities.count - instances.count else { throw .capacityExceeded }
        var pending: Set<EntityID> = []
        var bytes = identifierBytes
        for id in definitions {
            guard !identities.contains(id), pending.insert(id).inserted else { throw .duplicateIdentity(id) }
        }
        for id in definitions + references {
            guard id.key.utf8.count <= policy.maximumIdentifierBytes - bytes else { throw .capacityExceeded }
            bytes += id.key.utf8.count
        }
        identities.formUnion(pending); identifierBytes = bytes
    }

    // FIXME(INCOMPLETE_IMPLEMENTATION): The AF34 structural path reserves actual joint and
    // anchor identities before child callbacks. This added source-only admission path and
    // its unchanged legacy callers require original behavioral regression qualification.
    internal mutating func reserveStructuralJoint(id: EntityID, parentFrame: EntityID,
        childFrame: EntityID, parent: EntityID
    ) throws(MachineDefinitionFailure) -> (id: EntityID, parentFrame: EntityID, childFrame: EntityID) {
        guard structuralEnabled else {
            throw .compilation(.one(.unsupportedCapability, .input,
                message: "Structural identity reservation requires the structural facade."))
        }
        let absolute = try local(id), parentAnchor = try local(parentFrame), childAnchor = try local(childFrame)
        try admit([absolute, parentAnchor, childAnchor], references: [parent])
        structuralPendingJoints.insert(absolute)
        return (absolute, parentAnchor, childAnchor)
    }

    internal mutating func finishStructuralJoint(_ joint: MechanicalJoint) throws(MachineDefinitionFailure) {
        let record = joint.record
        guard structuralPendingJoints.contains(record.id), identities.contains(record.parentAnchor.frame),
              identities.contains(record.childAnchor.frame) else {
            throw .compilation(.one(.invalidInput, .input, records: [record.id],
                message: "Structural joint was not reserved by its lowering owner."))
        }
        try admit([], references: [record.childBody])
        joints.append(joint)
        structuralPendingJoints.remove(record.id)
    }

    internal mutating func reserveStructuralPhysics(_ id: EntityID,
        references: [EntityID]
    ) throws(MachineDefinitionFailure) -> EntityID {
        guard structuralEnabled else {
            throw .compilation(.one(.unsupportedCapability, .input, records: [id],
                message: "Physical machine declarations require structural-system compilation."))
        }
        let absolute = try local(id)
        try admit([absolute], references: references)
        return absolute
    }

    public mutating func append(_ body: MechanicalBody) throws(MachineDefinitionFailure) {
        let id = try local(body.id), frame = try local(body.frame)
        let mapped: MechanicalBody
        do {
            switch body {
            case .spatial(let record):
                mapped = .spatial(try BodyRecord3D(id: id, frame: frame, mode: record.mode,
                    bodyToWorld: record.bodyToWorld, representations: record.representations, inertia: record.inertia))
            case .planar(let record):
                mapped = .planar(try BodyRecord2D(id: id, frame: frame, mode: record.mode,
                    bodyToWorld: record.bodyToWorld, representations: record.representations, inertia: record.inertia))
            }
        } catch { throw .invalidBody(error) }
        try admit([id, frame])
        bodies.append(mapped)
    }

    public mutating func append(_ joint: MechanicalJoint, parent: MachineEntityReference,
                                child: MachineEntityReference) throws(MachineDefinitionFailure) {
        let record = joint.record
        let id = try local(record.id), parentFrame = try local(record.parentAnchor.frame), childFrame = try local(record.childAnchor.frame)
        let parentID = try resolve(parent), childID = try resolve(child)
        let mapped: MechanicalJoint
        do {
            mapped = MechanicalJoint(record: try JointRecord(id: id, parentBody: parentID, childBody: childID,
                parentAnchor: JointAnchor(frame: parentFrame, placement: record.parentAnchor.placement),
                childAnchor: JointAnchor(frame: childFrame, placement: record.childAnchor.placement), manifold: record.manifold), authority: joint.authority)
        } catch { throw .invalidJoint(error) }
        try admit([id, parentFrame, childFrame], references: [parentID, childID])
        joints.append(mapped)
    }
}
