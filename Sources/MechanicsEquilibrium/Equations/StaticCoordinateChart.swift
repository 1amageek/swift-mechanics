import MechanicsCore
import MechanicsModel
import MechanicsCompiler

/// Independent SI scalar q=v chart, with explicit compiler joint bindings.
public struct StaticCoordinateChart: Equatable, Sendable {
    public let stamp: ModelStamp
    public let frame: EntityID
    public let coordinateIDs: [UInt64]
    public let joints: [EntityID]
    public let dimensions: [PhysicalDimension]
    public let scales: [Double]
    public var count: Int { coordinateIDs.count }
    public init(stamp: ModelStamp, frame: EntityID, coordinateIDs: [UInt64], joints: [EntityID], dimensions: [PhysicalDimension], scales: [Double], limits: EquilibriumLimits) throws(EquilibriumError) {
        let n=coordinateIDs.count
        guard n > 0, n <= limits.coordinates, joints.count==n, dimensions.count==n, scales.count==n else { throw .capacityExceeded }
        try boundedIdentity(stamp.identity, limit: limits.identifierBytes)
        try boundedIdentity(frame.key, limit: limits.identifierBytes)
        guard frame.kind == .frame else { throw .invalidInput }
        for i in 0..<n {
            try boundedIdentity(joints[i].key, limit: limits.identifierBytes)
            guard joints[i].kind == .joint, scales[i].isFinite, scales[i]>0,
                dimensions[i] == .length || dimensions[i] == .angle else { throw .invalidInput }
            for j in 0..<i { guard coordinateIDs[i] != coordinateIDs[j], joints[i] != joints[j] else { throw .invalidInput } }
        }
        self.stamp=stamp; self.frame=frame; self.coordinateIDs=coordinateIDs; self.joints=joints; self.dimensions=dimensions; self.scales=scales
    }
}
