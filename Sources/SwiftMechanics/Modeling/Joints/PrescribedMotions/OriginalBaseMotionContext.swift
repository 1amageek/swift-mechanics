/// Immutable phase owner keeps future publication evidence outside opaque callback frames.
internal final class OriginalBaseMotionContext: Sendable {
    let original: PrescribedBaseMotionSample
    let reservedStorage: Int
    init(original: PrescribedBaseMotionSample, reservedStorage: Int) {
        self.original = original; self.reservedStorage = reservedStorage
    }
}
