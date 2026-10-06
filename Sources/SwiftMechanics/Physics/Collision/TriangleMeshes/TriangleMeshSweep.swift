public struct TriangleMeshSweep: Sendable {
    public let start: TriangleMesh
    public let end: TriangleMesh

    public init(start: TriangleMesh, end: TriangleMesh) throws(TriangleMeshError) {
        guard start.geometry == end.geometry else { throw .collision(.staleGeometry) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Rotating triangle-mesh CCD is not implemented.
        // Public mesh sphere sweeps consume this admission; success requires conservative
        // original-triangle rotation bounds and verified rotational TOI before admitting rotation.
        guard start.pose.rotation == end.pose.rotation || start.pose.rotation == end.pose.rotation.negated() else {
            throw .unsupportedSweep
        }
        self.start = start; self.end = end
    }

    public func mesh(at fraction: Double) throws(TriangleMeshError) -> TriangleMesh {
        guard fraction.isFinite, fraction >= 0, fraction <= 1 else { throw .collision(.invalidPolicy) }
        let position = try TriangleMeshMath.add(start.pose.translation,
            TriangleMeshMath.scale(TriangleMeshMath.sub(end.pose.translation, start.pose.translation), fraction))
        return start.moved(to: RigidTransform(rotation: start.pose.rotation, translation: position))
    }
}
