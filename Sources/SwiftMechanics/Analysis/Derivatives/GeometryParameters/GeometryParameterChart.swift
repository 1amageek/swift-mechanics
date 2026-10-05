public enum GeometryParameterChart: Equatable, Sendable {
    /// Parent-frame translation per metre of scalar parameter, at the exact reference placement.
    case translation(reference: RigidTransform, perMeter: Vector3)
    /// Right-body rotation tangent per radian of scalar parameter; translation is fixed.
    case rotation(reference: RigidTransform, bodyPerRadian: Vector3)
    /// Dimensionless raw-axis component change before the actual unit-axis normalizer.
    case normalizedAxis(rawReference: Vector3, rawPerUnit: Vector3)
    public var dimension: PhysicalDimension {
        switch self { case .translation: return .length; case .rotation: return .angle; case .normalizedAxis: return .dimensionless }
    }
}
