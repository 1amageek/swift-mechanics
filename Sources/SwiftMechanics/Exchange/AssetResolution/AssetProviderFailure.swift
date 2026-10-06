public enum AssetProviderFailure: Error, Sendable {
    case invalidLimits, missing, ambiguous, sourceFailure(code: UInt32), cancelled, arithmeticOverflow
    case limit(AssetResource, Int)
}
