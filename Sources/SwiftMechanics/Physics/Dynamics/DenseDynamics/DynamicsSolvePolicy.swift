public struct DynamicsSolvePolicy: Sendable {
    public let capability: LinearCapability
    public let linearTolerance: LinearTolerance<Double>
    public let coordinateScales: [Double]
    public let energyScale: Double
    public let timeScale: Double
    public init(capability: LinearCapability, linearTolerance: LinearTolerance<Double>, coordinateScales: [Double],
                energyScale: Double, timeScale: Double) throws(DynamicsError) {
        guard coordinateScales.allSatisfy({ $0.isFinite && $0 > 0 }), energyScale.isFinite, energyScale > 0,
              timeScale.isFinite, timeScale > 0 else { throw .invalidInput }
        let squared = timeScale*timeScale
        guard squared.isFinite, squared > 0 else { throw .invalidInput }
        for scale in coordinateScales {
            guard (scale/energyScale).isFinite, scale/energyScale > 0,
                  (scale/squared).isFinite, scale/squared > 0 else { throw .invalidInput }
        }
        self.capability = capability; self.linearTolerance = linearTolerance; self.coordinateScales = coordinateScales
        self.energyScale = energyScale; self.timeScale = timeScale
    }
}
