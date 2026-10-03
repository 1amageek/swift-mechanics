import MechanicsCore
import MechanicsModel

public struct KinematicTree: Sendable {
    public let bodies: [KinematicBody]
    public let joints: [JointRecord]
    public let rootBase: BaseLayout
    public let worldFrame: EntityID
    public let revision: UInt64
    public let layout: TreeCoordinateLayout
    public let frameCount: Int
    internal let parentIndices: [Int]
    internal let bodyIndices: [EntityID: Int]
    internal let prescribedFrames: Set<EntityID>

    public init(bodies inputBodies: [KinematicBody], joints inputJoints: [JointRecord], root: EntityID,
                rootBase: BaseLayout, worldFrame: EntityID, revision: UInt64, capacity: KinematicCapacity) throws {
        guard worldFrame.kind == .frame, root.kind == .body else { throw JointError.identityKindMismatch }
        guard !inputBodies.isEmpty else { throw JointError.invalidRoot }
        guard inputBodies.count <= capacity.maximumBodies else { throw JointError.capacityExceeded }
        var indices: [EntityID: Int] = [:]
        var identities: Set<EntityID> = [worldFrame]
        for (index, body) in inputBodies.enumerated() {
            for id in [body.id, body.frame] {
                guard identities.insert(id).inserted else { throw JointError.duplicateIdentity(id) }
            }
            indices[body.id] = index
        }
        guard let rootIndex = indices[root] else { throw JointError.invalidRoot }
        let dimension = inputBodies[rootIndex].dimension
        guard inputBodies.allSatisfy({ $0.dimension == dimension }) else { throw JointError.mixedDimensions }
        if dimension == .planar && rootBase == .spatialFloating { throw JointError.nonplanarGeometry }
        var children = [[Int]](repeating: [], count: inputBodies.count)
        var incoming = [Int](repeating: 0, count: inputBodies.count)
        var prescribed: Set<EntityID> = []
        for (index, joint) in inputJoints.enumerated() {
            for id in [joint.id, joint.parentAnchor.frame, joint.childAnchor.frame] {
                guard identities.insert(id).inserted else { throw JointError.duplicateIdentity(id) }
            }
            guard let parent = indices[joint.parentBody] else { throw JointError.danglingBody(joint.parentBody) }
            guard let child = indices[joint.childBody] else { throw JointError.danglingBody(joint.childBody) }
            incoming[child] += 1
            guard incoming[child] == 1 else { throw JointError.multipleParents(joint.childBody) }
            children[parent].append(index)
            for anchor in [joint.parentAnchor, joint.childAnchor] {
                switch anchor.placement {
                case .prescribed: prescribed.insert(anchor.frame)
                case .fixed(let pose):
                    if dimension == .planar { try Self.validatingPlanar(pose) }
                }
            }
            if dimension == .planar && !joint.manifold.preservesWorldXYPlane { throw JointError.nonplanarGeometry }
        }
        // Kahn traversal detects cycles in disconnected components as well as at root.
        var indegrees = incoming
        var acyclicQueue = indegrees.indices.filter { indegrees[$0] == 0 }
        var cursor = 0
        while cursor < acyclicQueue.count {
            let parent = acyclicQueue[cursor]; cursor += 1
            for jointIndex in children[parent] {
                guard let child = indices[inputJoints[jointIndex].childBody] else { throw JointError.disconnectedTree }
                indegrees[child] -= 1
                if indegrees[child] == 0 { acyclicQueue.append(child) }
            }
        }
        guard acyclicQueue.count == inputBodies.count else { throw JointError.cycle }
        guard incoming[rootIndex] == 0 else { throw JointError.invalidRoot }
        guard incoming.indices.allSatisfy({ $0 == rootIndex || incoming[$0] == 1 }) else { throw JointError.disconnectedTree }
        var order = [rootIndex]
        var orderedJoints: [JointRecord] = []
        var parents = [0]
        cursor = 0
        while cursor < order.count {
            let parentInput = order[cursor]
            for index in children[parentInput] {
                let joint = inputJoints[index]
                guard let child = indices[joint.childBody] else { throw JointError.disconnectedTree }
                order.append(child); parents.append(cursor); orderedJoints.append(joint)
            }
            cursor += 1
        }
        guard order.count == inputBodies.count else { throw JointError.disconnectedTree }
        var positionCount = rootBase.positionCount, velocityCount = rootBase.velocityCount
        var jointLayouts: [JointCoordinateLayout] = []
        jointLayouts.reserveCapacity(orderedJoints.count)
        for joint in orderedJoints {
            let q = try CoordinateRange(start: positionCount, count: joint.manifold.positionCount)
            let v = try CoordinateRange(start: velocityCount, count: joint.manifold.velocityCount)
            jointLayouts.append(JointCoordinateLayout(joint: joint.id, positions: q, velocities: v))
            positionCount = q.end; velocityCount = v.end
        }
        try capacity.validating(bodyCount: order.count, velocityCount: velocityCount)
        let (anchorCount, anchorOverflow) = orderedJoints.count.multipliedReportingOverflow(by: 2)
        let bodyAndWorld = try CoordinateRange(start: order.count, count: 1)
        guard !anchorOverflow else { throw JointError.integerOverflow }
        let allFrames = try CoordinateRange(start: bodyAndWorld.end, count: anchorCount)
        self.frameCount = allFrames.end
        let orderedBodies = order.map { inputBodies[$0] }
        self.bodies = orderedBodies; self.joints = orderedJoints
        self.rootBase = rootBase; self.worldFrame = worldFrame; self.revision = revision
        self.parentIndices = parents
        self.bodyIndices = Dictionary(uniqueKeysWithValues: orderedBodies.enumerated().map { ($1.id, $0) })
        self.prescribedFrames = prescribed
        self.layout = TreeCoordinateLayout(bodyOrder: orderedBodies.map { $0.id }, joints: jointLayouts,
                                           positionCount: positionCount, velocityCount: velocityCount)
    }

    internal static func validatingPlanar(_ pose: RigidTransform) throws(JointError) {
        guard pose.translation.z == 0, pose.rotation.x == 0, pose.rotation.y == 0 else { throw .nonplanarGeometry }
    }

    public func bodyIndex(_ id: EntityID) throws(JointError) -> Int {
        guard let index = bodyIndices[id] else { throw .unknownBody(id) }
        return index
    }
}
