
public enum JointSpecification: Equatable, Sendable {
    case fixed
    case revolute(axis: Vector3)
    case prismatic(axis: Vector3)
    case spherical
    case universal(firstAxis: Vector3, secondAxis: Vector3)
    case cylindrical(axis: Vector3)
    case planar(firstTranslationAxis: Vector3, secondTranslationAxis: Vector3)
    case screw(axis: Vector3, pitchMetersPerRadian: Double)
    case sixDOF
    case custom(orderedAxes: [JointAxis])
}
