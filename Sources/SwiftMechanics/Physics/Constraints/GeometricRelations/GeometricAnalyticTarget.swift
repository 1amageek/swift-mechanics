/// Exact quadratic target in physical seconds; coefficients carry the row's SI target units.
public struct GeometricAnalyticTarget: Equatable, Sendable {
    public let value: Vector3
    public let rate: Vector3
    public let second: Vector3
    public let referenceTime: Double
    public var isExplicitTime: Bool { rate != .zero || second != .zero }
    public init(value: Vector3 = .zero, rate: Vector3 = .zero, second: Vector3 = .zero, referenceTime: Double = 0) throws(GeometricConstraintError) {
        guard referenceTime.isFinite else { throw .invalidInput }
        self.value=value;self.rate=rate;self.second=second;self.referenceTime=referenceTime
    }
    internal func sample(_ time: Double) throws(GeometricConstraintError) -> (value: Vector3, rate: Vector3) {
        let dt=time-referenceTime
        return try GeometricArithmetic.geometry {
            (try value.adding(rate.scaled(by:dt)).adding(second.scaled(by:0.5*dt*dt)), try rate.adding(second.scaled(by:dt)))
        }
    }
}
