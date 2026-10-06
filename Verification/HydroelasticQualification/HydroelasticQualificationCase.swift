public enum HydroelasticQualificationCase: CaseIterable, Sendable {
    case rigidTriangle
    case rigidQuadrilateral
    case twoFieldsReciprocal
    case currentGeometryAndCovariance
    case domainsAndStaleness
    case budgetsAndCancellation

    public var label: String {
        switch self {
        case .rigidTriangle: "rigid triangle"
        case .rigidQuadrilateral: "rigid quadrilateral"
        case .twoFieldsReciprocal: "two fields reciprocal"
        case .currentGeometryAndCovariance: "current geometry and covariance"
        case .domainsAndStaleness: "domains and staleness"
        case .budgetsAndCancellation: "budgets and cancellation"
        }
    }
}
