public struct StationaryLoadSample: Sendable {
    public let physical:KinematicState
    public let programID:UInt64
    public let revision:UInt64
    public let gravity:AffineGravity?
    public let contribution:GeneralizedForceContribution
    public let dependencyCoordinateIDs:[UInt64]
    internal init(physical:KinematicState,program:StationaryLoadProgram,contribution:GeneralizedForceContribution,support:[UInt64]) {
        self.physical=physical;programID=program.id;revision=program.revision;gravity=program.gravity;self.contribution=contribution;dependencyCoordinateIDs=support
    }
}
