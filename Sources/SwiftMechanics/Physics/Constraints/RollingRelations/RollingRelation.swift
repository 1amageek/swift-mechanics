/// Immutable physical/source binding; retaining this value grants no solver acceptance authority.
public struct RollingRelation: Sendable {
    public let model: CompiledMechanicalModel
    public let sourceID: String
    public let sourceRevision: UInt64
    public let referenceTime: Double
    public let wheel: RollingWheel
    public let plane: RollingPlaneBinding
    /// Ordered normal, forward and lateral rows; no tangential position equations exist.
    public let rowIDs: [UInt64]

    public init(model: CompiledMechanicalModel, sourceID: String, sourceRevision: UInt64,
                referenceTime: Double, wheel: RollingWheel, plane: RollingPlaneBinding,
                rowIDs: [UInt64]) throws(RollingError) {
        guard !sourceID.isEmpty, referenceTime.isFinite, rowIDs.count == 3,
              rowIDs[0] != rowIDs[1], rowIDs[0] != rowIDs[2], rowIDs[1] != rowIDs[2] else {
            throw .invalidInput
        }
        self.model = model; self.sourceID = sourceID; self.sourceRevision = sourceRevision
        self.referenceTime = referenceTime; self.wheel = wheel; self.plane = plane; self.rowIDs = rowIDs
    }
}
