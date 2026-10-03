import MechanicsCore
import MechanicsModel
public struct CableRouteResponse: Equatable, Sendable {
    public let frame: EntityID
    public let length: Double
    public let coordinateGradient: [Double]
    public let waypointGradient: [Vector3]
    public let virtualLengthRate: Double
    public let prescribedLengthRate: Double
    public let directionalSecondDerivative: Double
    internal init(frame: EntityID, length: Double, coordinateGradient: [Double], waypointGradient: [Vector3],
                  virtualLengthRate: Double, prescribedLengthRate: Double, directionalSecondDerivative: Double) {
        self.frame = frame; self.length = length; self.coordinateGradient = coordinateGradient
        self.waypointGradient = waypointGradient; self.virtualLengthRate = virtualLengthRate
        self.prescribedLengthRate = prescribedLengthRate; self.directionalSecondDerivative = directionalSecondDerivative
    }
    public func actualLengthRate() throws(LoadError) -> Double { try loadFinite(virtualLengthRate + prescribedLengthRate) }
    /// Generalized pulling load = -T*dL/dq; zero tension is a declared slack load, not a failed route.
    public func generalizedPull(tension: Double, work: inout LoadWork) throws(LoadError) -> [Double] {
        guard tension.isFinite, tension >= 0 else { throw .invalidPassiveLaw }
        try work.reserve(scalars: coordinateGradient.count)
        var result = [Double](repeating: 0, count: coordinateGradient.count)
        for i in result.indices { try work.charge(1); result[i] = try loadFinite(-tension * coordinateGradient[i]) }
        return result
    }
}
