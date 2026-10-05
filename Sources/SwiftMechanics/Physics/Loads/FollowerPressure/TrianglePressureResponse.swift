public struct TrianglePressureResponse: Sendable, Equatable {
    public let body: EntityID
    public let frame: EntityID
    public let nodalLoads: [FramedPointLoad]
    /// Three exact 3x3 blocks d(force at any node)/d(vertex j), in original vertex order.
    public let forceVertexDerivatives: [Matrix3]
    public let resultant: SpatialWrench
    public let referencePoint: Vector3
    public let mechanicalPower: Double
    internal init(body: EntityID, frame: EntityID, nodalLoads: [FramedPointLoad], forceVertexDerivatives: [Matrix3],
                  resultant: SpatialWrench, referencePoint: Vector3, mechanicalPower: Double) {
        self.body = body; self.frame = frame; self.nodalLoads = nodalLoads
        self.forceVertexDerivatives = forceVertexDerivatives; self.resultant = resultant
        self.referencePoint = referencePoint; self.mechanicalPower = mechanicalPower
    }
}
