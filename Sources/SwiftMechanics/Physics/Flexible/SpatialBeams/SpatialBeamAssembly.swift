/// Dense row-major 12 by 12 operators in the identified reference frame.
public struct SpatialBeamAssembly: Equatable, Sendable {
    public let beam: SpatialBeamDefinition
    public let frame: SpatialBeamFrame
    public let elasticStiffness: [Double]
    public let mass: [Double]
    public let damping: [Double]
    internal let localStiffness: [Double]
    internal let localMass: [Double]
    internal let localDamping: [Double]
    internal let constitutiveDiagonal: [Double]
    internal let interpolationFactors: [Double]
    internal init(beam: SpatialBeamDefinition, frame: SpatialBeamFrame, elasticStiffness: [Double],
                  mass: [Double], damping: [Double], localStiffness: [Double], localMass: [Double],
                  localDamping: [Double], constitutiveDiagonal: [Double], interpolationFactors: [Double]) {
        self.beam = beam; self.frame = frame; self.elasticStiffness = elasticStiffness
        self.mass = mass; self.damping = damping; self.localStiffness = localStiffness
        self.localMass = localMass; self.localDamping = localDamping
        self.constitutiveDiagonal = constitutiveDiagonal; self.interpolationFactors = interpolationFactors
    }
}
