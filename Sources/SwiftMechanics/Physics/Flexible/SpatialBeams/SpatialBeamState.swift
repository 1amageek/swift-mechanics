/// Displacements [m], infinitesimal rotations [rad], and their rates in the reference frame.
public struct SpatialBeamState: Equatable, Sendable {
    public let beam: SpatialBeamDefinition
    public let displacement: [Double]
    public let velocity: [Double]
    public init(beam: SpatialBeamDefinition,
                displacement: [Double], velocity: [Double]) throws(SpatialBeamError) {
        guard displacement.count == 12, velocity.count == 12,
              displacement.allSatisfy({ $0.isFinite }), velocity.allSatisfy({ $0.isFinite }) else {
            throw .invalidInput(parameter: "beamState")
        }
        self.beam = beam
        self.displacement = displacement; self.velocity = velocity
    }
}
