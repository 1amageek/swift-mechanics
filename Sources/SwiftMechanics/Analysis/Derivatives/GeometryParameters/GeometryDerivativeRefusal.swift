public enum GeometryDerivativeRefusal: Equatable, Sendable {
    case topologyChange
    case nonSpatialTree
    case floatingRoot
    case movingAnchor
    case unsupportedJointChart
    case zeroOrBoundaryAxis
    case sourceMapping
    case referenceChartMismatch
}
