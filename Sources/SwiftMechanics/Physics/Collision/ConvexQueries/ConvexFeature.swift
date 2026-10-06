public enum ConvexFeature: Equatable, Sendable {
    case analytic(CollisionFeature)
    case capsuleEnd(positive: Bool)
    case cylinderRim(positive: Bool)
    case cylinderCap(positive: Bool)
    case coneApex
    case coneBaseRim
    case coneBase
    case hullVertex(index: Int)
}
