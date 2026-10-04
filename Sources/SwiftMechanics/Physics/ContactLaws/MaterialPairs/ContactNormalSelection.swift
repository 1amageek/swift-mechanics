public enum ContactNormalSelection: Equatable, Sendable {
    case linear(maximumPenetration: Double, maximumNormalSpeed: Double)
    case hertz(effectiveRadius: Double, maximumPenetration: Double, maximumNormalSpeed: Double)
    case huntCrossley(effectiveRadius: Double, maximumPenetration: Double, maximumNormalSpeed: Double)
}
