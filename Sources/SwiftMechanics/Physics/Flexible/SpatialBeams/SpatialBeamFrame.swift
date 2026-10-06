public struct SpatialBeamFrame: Equatable, Sendable {
    public let length: Double
    /// Columns are local x/y/z expressed in the reference frame.
    public let localToReference: Matrix3
    internal init(length: Double, localToReference: Matrix3) {
        self.length = length; self.localToReference = localToReference
    }
}
