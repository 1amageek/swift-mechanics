
/// Structural joint/root constraints certified by regular local charts and connected-tree independence.
public struct StructuralTreeRank: Equatable, Sendable {
    public let rank: Int
    public let ambientBodyVelocityCount: Int
    public let generalizedVelocityCount: Int
    public let dimension: KinematicDimension
    public let configurationTime: Double

    /// Scope excludes prescribed-coordinate equations, mode laws and all future loop/force equations.
    internal init(rank: Int, ambientBodyVelocityCount: Int, generalizedVelocityCount: Int,
                  dimension: KinematicDimension, configurationTime: Double) {
        self.rank = rank; self.ambientBodyVelocityCount = ambientBodyVelocityCount
        self.generalizedVelocityCount = generalizedVelocityCount; self.dimension = dimension; self.configurationTime = configurationTime
    }
}
