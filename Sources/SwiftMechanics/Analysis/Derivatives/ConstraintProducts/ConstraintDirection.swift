public struct ConstraintDirection: Sendable {
    public let layoutRevision: UInt64
    public let position: [Double]
    public let velocity: [Double]
    public let time: Double
    public let coefficients: [ConstraintCoefficientDirection]
    public init(layoutRevision: UInt64, position: [Double], velocity: [Double], time: Double, coefficients: [ConstraintCoefficientDirection]) {
        self.layoutRevision=layoutRevision; self.position=position; self.velocity=velocity; self.time=time; self.coefficients=coefficients
    }
}
