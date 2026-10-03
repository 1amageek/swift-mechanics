public struct QuadraticConstraint: Sendable {
    public let id: UInt64
    public let constant: Double
    public let linear: [Double]
    public let hessian: [Double]
    public let timeLinear: Double
    public let timeQuadratic: Double
    public let mixedTime: [Double]
    public init(id: UInt64, constant: Double, linear: [Double], hessian: [Double], timeLinear: Double, timeQuadratic: Double, mixedTime: [Double]) {
        self.id=id; self.constant=constant; self.linear=linear; self.hessian=hessian
        self.timeLinear=timeLinear; self.timeQuadratic=timeQuadratic; self.mixedTime=mixedTime
    }
}
