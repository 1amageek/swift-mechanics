public enum MassPropertyOrigin: Equatable, Sendable {
    case supplied
    case analyticPrimitive
    case compound(overlapPolicy: CompoundOverlapPolicy)
}
