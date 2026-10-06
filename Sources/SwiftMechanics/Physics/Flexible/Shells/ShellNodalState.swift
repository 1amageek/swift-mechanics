/// Local row-major nodal [u,v,w,betaX,betaY] coordinates and their time rates.
public struct ShellNodalState: Sendable {
    public let plateIdentity: String
    public let plateRevision: UInt64
    public let frame: EntityID
    public let source: SourceProvenance
    public let coordinates: [Double]
    public let velocities: [Double]

    public init(plateIdentity: String, plateRevision: UInt64, frame: EntityID, source: SourceProvenance,
                coordinates: [Double], velocities: [Double]) throws(ShellError) {
        guard !plateIdentity.isEmpty, frame.kind == .frame, !coordinates.isEmpty,
              coordinates.count == velocities.count, coordinates.count % 5 == 0,
              coordinates.allSatisfy({ $0.isFinite }), velocities.allSatisfy({ $0.isFinite }) else {
            throw .invalidLayout
        }
        self.plateIdentity = plateIdentity; self.plateRevision = plateRevision; self.frame = frame; self.source = source
        self.coordinates = coordinates; self.velocities = velocities
    }
}
