import MechanicsModel
import MechanicsCollision
public struct GranularParticle: Sendable {
    public let proxy: CollisionProxy
    public let body: ModelReference
    public let material: ModelReference
    public let mass: Double, radius: Double, momentOfInertia: Double
    public init(proxy: CollisionProxy, body: ModelReference, material: ModelReference, mass: Double) throws(GranularError) {
        guard body.id.kind == .body, material.id.kind == .material,
            mass.isFinite, mass > 0, proxy.geometry.margin == 0, proxy.geometry.approximationError == 0, proxy.geometry.resolution == .analytic else { throw .invalidInput }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Particle admission currently supports untextured solid spheres only.
        // Non-sphere DEM callers must fail until mass/orientation/contact integration is physically qualified.
        guard case .sphere(let r)=proxy.geometry.shape else { throw .unsupportedDomain }
        let inertia=0.4*mass*r*r
        guard r > 0, inertia.isFinite, inertia > 0 else { throw .invalidInput }
        self.proxy=proxy; self.body=body; self.material=material; self.mass=mass; radius=r; momentOfInertia=inertia
    }
}
