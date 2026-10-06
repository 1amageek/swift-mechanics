/// Supplied by the opaque CAD owner, never synthesized from MJCF geoms.
public struct MJCFGeometryBinding: Sendable {
    public let bodyName: String
    public let representations: BodyRepresentations
    public init(bodyName: String, representations: BodyRepresentations) { self.bodyName = bodyName; self.representations = representations }
}
