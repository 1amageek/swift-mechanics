/// Rectangular Gram factors define K=B^T*B and C=D^T*D on an independent six-coordinate chart.
public struct PassiveChartBushing: Equatable, Sendable {
    public let frame: EntityID
    public let stiffnessFactor: [Double]
    public let dampingFactor: [Double]
    public let maximumAbsoluteStrain: [Double]
    public let maximumAbsoluteRate: [Double]
    public init(frame: EntityID, stiffnessFactor: [Double], dampingFactor: [Double],
                maximumAbsoluteStrain: [Double], maximumAbsoluteRate: [Double]) throws(LoadError) {
        guard frame.kind == .frame else { throw .invalidInput }
        guard stiffnessFactor.count % 6 == 0, dampingFactor.count % 6 == 0,
              maximumAbsoluteStrain.count == 6, maximumAbsoluteRate.count == 6 else { throw .invalidShape }
        guard stiffnessFactor.allSatisfy({ $0.isFinite }), dampingFactor.allSatisfy({ $0.isFinite }),
              maximumAbsoluteStrain.allSatisfy({ $0.isFinite && $0 > 0 }),
              maximumAbsoluteRate.allSatisfy({ $0.isFinite && $0 >= 0 }) else { throw .invalidPassiveLaw }
        self.frame = frame
        self.stiffnessFactor = stiffnessFactor; self.dampingFactor = dampingFactor
        self.maximumAbsoluteStrain = maximumAbsoluteStrain; self.maximumAbsoluteRate = maximumAbsoluteRate
    }
}
