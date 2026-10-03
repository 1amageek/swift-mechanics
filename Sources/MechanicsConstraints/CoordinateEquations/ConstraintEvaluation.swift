public struct ConstraintEvaluation: Sendable {
    public let normalizedPosition: [Double]
    public let normalizedVelocity: [Double]
    public let values: [Double]
    public let jacobian: [Double]
    public let timeDerivative: [Double]
    public let accelerationBias: [Double]
    public let rowIDs: [UInt64]
    public let layoutRevision: UInt64
    public init(normalizedPosition: [Double], normalizedVelocity: [Double], values: [Double], jacobian: [Double], timeDerivative: [Double], accelerationBias: [Double], rowIDs: [UInt64], layoutRevision: UInt64) {
        self.normalizedPosition=normalizedPosition; self.normalizedVelocity=normalizedVelocity; self.values=values; self.jacobian=jacobian
        self.timeDerivative=timeDerivative; self.accelerationBias=accelerationBias; self.rowIDs=rowIDs; self.layoutRevision=layoutRevision
    }
}
