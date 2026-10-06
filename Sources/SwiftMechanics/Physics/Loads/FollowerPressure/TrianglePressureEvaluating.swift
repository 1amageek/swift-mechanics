public protocol TrianglePressureEvaluating: Sendable {
    /// Vertex order specifies outward orientation; positive pressure acts inward.
    func evaluate(pressure: Double, body: EntityID, frame: EntityID, vertices: [Vector3], velocities: [Vector3],
                  referencePoint: Vector3, minimumTwiceArea: Double, work: inout LoadWork) throws(LoadError) -> TrianglePressureResponse
}
