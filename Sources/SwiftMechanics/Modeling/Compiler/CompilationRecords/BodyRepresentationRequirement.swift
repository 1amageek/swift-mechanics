
public struct BodyRepresentationRequirement: Equatable, Sendable {
    public let body: EntityID
    public let geometry: [RepresentationKind]
    public let inertia: InertiaRepresentationRequirement

    public init(body: EntityID, geometry: [RepresentationKind], inertia: InertiaRepresentationRequirement) {
        self.body = body; self.geometry = geometry; self.inertia = inertia
    }
}
