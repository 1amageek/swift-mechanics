public final class StationaryIslandMotion: Sendable {
    public let program: StationaryIslandProgram
    public let island: StationaryMechanicalIsland
    public let physical: KinematicState
    public let system: RigidDynamicsSystem
    public let acceleration: [Double]
    public let generalizedReaction: [Double]
    public let kineticEnergy: Double
    public let constrained: ConstrainedMotion?
    internal init(program: StationaryIslandProgram, island: StationaryMechanicalIsland, physical: KinematicState,
                  system: RigidDynamicsSystem, acceleration: [Double], reaction: [Double], energy: Double,
                  constrained: ConstrainedMotion?) {
        self.program=program; self.island=island; self.physical=physical; self.system=system
        self.acceleration=acceleration; generalizedReaction=reaction; kineticEnergy=energy; self.constrained=constrained
    }
}
