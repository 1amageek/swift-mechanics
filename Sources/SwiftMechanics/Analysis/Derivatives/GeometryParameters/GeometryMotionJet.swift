internal struct GeometryMotionJet: Sendable {
    let angular: GeometryVectorJet
    let linear: GeometryVectorJet
    init(_ angular: GeometryVectorJet, _ linear: GeometryVectorJet) { self.angular = angular; self.linear = linear }
    static let zero = GeometryMotionJet(.zero, .zero)
    var value: SpatialMotion { SpatialMotion(angular: angular.value, linear: linear.value) }
    var direction: SpatialMotion { SpatialMotion(angular: angular.direction, linear: linear.direction) }
}
