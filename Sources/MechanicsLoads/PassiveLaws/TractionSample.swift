import MechanicsCore
/// Fixed independent quadrature point, area m^2 and force/area N/m^2.
public struct TractionSample: Equatable, Sendable {
    public let point: Vector3
    public let area: Double
    public let traction: Vector3
    public init(point: Vector3, area: Double, traction: Vector3) throws(LoadError) {
        guard area.isFinite, area > 0 else { throw .invalidInput }
        self.point = point; self.area = area; self.traction = traction
    }
    /// Positive pressure pushes opposite the outward normal.
    public init(point: Vector3, area: Double, outwardNormal: Vector3, pressure: Double) throws(LoadError) {
        guard pressure.isFinite, pressure >= 0 else { throw .invalidInput }
        try self.init(point: point, area: area, traction: loadCore { () throws(CoreError) in try outwardNormal.normalized().scaled(by: -pressure) })
    }
}
