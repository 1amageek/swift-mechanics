/// Owner-issued material coordinates. The retained surface is the physical identity authority.
public final class AttachmentMaterialSite: Sendable {
    public let surface: MaterialSurface
    public let material: SurfaceMaterialPoint

    internal init(surface: MaterialSurface, material: SurfaceMaterialPoint) {
        self.surface = surface; self.material = material
    }
}
