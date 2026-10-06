public struct ConstrainedSleepEvolutionWork: Sendable {
    public var numerical:NumericalWork
    public var collision:CollisionWork
    public var contact:ContactWork
    public var loads:LoadWork
    public var islands:IslandSleepWork
    /// Initial full source admission only; query and final Runtime admission remain their original bounded validation scopes.
    public internal(set) var checkpointAdmission:IslandSleepWork?
    public internal(set) var queries=0
    public internal(set) var rootIterations=0
    public internal(set) var acceptedSegments=0
    public internal(set) var acceptedImpacts=0
    public internal(set) var failedSupplierWorkUnavailable=false
    public init(numerical:NumericalWork,collision:CollisionWork,contact:ContactWork,loads:LoadWork,islands:IslandSleepWork) {
        self.numerical=numerical;self.collision=collision;self.contact=contact;self.loads=loads;self.islands=islands
    }
}
