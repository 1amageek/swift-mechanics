public struct URDFGeometryRecord: Sendable {
    public enum Usage: Sendable { case visual, collision }
    public enum Geometry: Sendable {
        case box(size: Vector3), sphere(radius: Double), cylinder(radius: Double, length: Double)
        case mesh(reference: URDFAssetReference, scale: Vector3)
    }
    public let body: EntityID
    public let usage: Usage
    public let geometry: Geometry
    public let geometryToBody: RigidTransform
    public let location: XMLLocation
    internal init(body: EntityID, usage: Usage, geometry: Geometry, geometryToBody: RigidTransform, location: XMLLocation) {
        self.body = body; self.usage = usage; self.geometry = geometry
        self.geometryToBody = geometryToBody; self.location = location
    }
}
