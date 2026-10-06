public enum SliderCrankAssembly: Equatable, Sendable {
    case positiveRodProjection
    case negativeRodProjection
    internal var sign: Double {
        switch self {
        case .positiveRodProjection: return 1
        case .negativeRodProjection: return -1
        }
    }
}
