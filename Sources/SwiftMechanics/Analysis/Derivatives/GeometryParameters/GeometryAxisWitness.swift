public struct GeometryAxisWitness: Sendable {
    public let parameterID: UInt64
    public let rawReference: Vector3
    public let normalizedAxis: Vector3
    public let normalizedDirection: Vector3
    internal init(parameterID: UInt64, rawReference: Vector3, normalizedAxis: Vector3, normalizedDirection: Vector3) {
        self.parameterID = parameterID; self.rawReference = rawReference; self.normalizedAxis = normalizedAxis
        self.normalizedDirection = normalizedDirection
    }
}
