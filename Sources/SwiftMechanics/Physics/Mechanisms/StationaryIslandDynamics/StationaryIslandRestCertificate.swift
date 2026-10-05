public final class StationaryIslandRestCertificate: Sendable {
    public let program: StationaryIslandProgram
    public let islandID: UInt64
    public let position: [Double]
    public let kineticEnergy: Double
    public let normalizedVelocity: Double
    internal init(motion: StationaryIslandMotion, speed: Double) {
        program=motion.program; islandID=motion.island.id
        position=motion.island.sourceCoordinateIndices.map { motion.physical.q[$0] }
        kineticEnergy=motion.kineticEnergy; normalizedVelocity=speed
    }
}
