public enum RefinementQualificationCase: CaseIterable, Sendable {
    case topologyAndBoundary, diagonalGeometry, sharedAndDisconnected
    case stateAndConcentratedLoads, originalRefusals, resourcesAndCancellation
    public var label: String {
        switch self {
        case .topologyAndBoundary:return "topology and boundary"
        case .diagonalGeometry:return "actual central diagonal geometry"
        case .sharedAndDisconnected:return "shared-face and disconnected conformity"
        case .stateAndConcentratedLoads:return "state and concentrated-load duality"
        case .originalRefusals:return "original typed refusals"
        case .resourcesAndCancellation:return "resources and cancellation"
        }
    }
}
