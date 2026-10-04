public enum CollisionFeature: Equatable, Sendable {
    case sphere
    case boxFace(axis: Int, positive: Bool)
    case boxBoundary(axisMask: Int, positiveMask: Int)
    case boxVertex(positiveMask: Int)
    case halfSpace

    public var orderCode: Int {
        switch self {
        case .sphere: 0
        case .halfSpace: 1
        case .boxFace(let axis, let positive): 2+2*axis+(positive ? 1 : 0)
        case .boxBoundary(let mask, let positive): 16+8*mask+positive
        case .boxVertex(let positive): 80+positive
        }
    }
}
