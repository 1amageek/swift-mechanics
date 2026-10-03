public struct BeamAssembly: Sendable {
    public let beam: UniformBeam
    public let youngModulus: Double
    public let coordinateCount: Int
    public let elasticStiffness: [Double]
    public let geometricStiffness: [Double]
    public let mass: [Double]
    public let damping: [Double]
    internal init(beam: UniformBeam, youngModulus: Double, coordinateCount: Int, elasticStiffness: [Double], geometricStiffness: [Double], mass: [Double], damping: [Double]) {
        self.beam=beam;self.youngModulus=youngModulus;self.coordinateCount=coordinateCount
        self.elasticStiffness=elasticStiffness;self.geometricStiffness=geometricStiffness;self.mass=mass;self.damping=damping
    }
}
