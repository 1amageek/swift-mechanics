import MechanicsCore
internal struct DifferentialMotion: Sendable {
    let angular: DifferentialVector
    let linear: DifferentialVector
    init(_ angular: DifferentialVector = .zero, _ linear: DifferentialVector = .zero) { self.angular=angular; self.linear=linear }
    static let zero = DifferentialMotion()
    var direction: SpatialMotion { SpatialMotion(angular:angular.direction,linear:linear.direction) }
}
