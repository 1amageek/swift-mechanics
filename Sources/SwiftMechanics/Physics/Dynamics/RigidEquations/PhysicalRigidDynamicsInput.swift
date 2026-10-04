/// Immutable original source. The inactive dimension has no substitute inertia inventory.
public final class PhysicalRigidDynamicsInput: Sendable {
    public enum Source: Sendable {
        case spatial(RigidDynamicsInput)
        case planar(PlanarRigidDynamicsInput)
    }
    private enum Storage: Sendable {
        case spatial(SpatialRigidDynamicsSource)
        case planar(PlanarRigidDynamicsSource)
    }
    private let storage: Storage
    public var source: Source {
        switch storage {
        case .spatial(let owner): return .spatial(owner.input)
        case .planar(let owner): return .planar(owner.input)
        }
    }
    public init(spatial: RigidDynamicsInput) { storage = .spatial(SpatialRigidDynamicsSource(spatial)) }
    public init(planar: PlanarRigidDynamicsInput) { storage = .planar(PlanarRigidDynamicsSource(planar)) }
    public var dimension: KinematicDimension {
        switch storage { case .spatial: return .spatial; case .planar: return .planar }
    }
    public var snapshot: KinematicSnapshot {
        switch storage { case .spatial(let owner): return owner.input.snapshot; case .planar(let owner): return owner.input.snapshot }
    }
    public var velocity: [Double] {
        switch storage { case .spatial(let owner): return owner.input.velocity; case .planar(let owner): return owner.input.velocity }
    }
    public var gravity: AffineGravity? {
        switch storage { case .spatial(let owner): return owner.input.gravity; case .planar(let owner): return owner.input.gravity }
    }
    public var bodyWrenches: [BodyWrenchContribution] {
        switch storage { case .spatial(let owner): return owner.input.bodyWrenches; case .planar(let owner): return owner.input.bodyWrenches }
    }
    public var generalizedForces: [GeneralizedForceContribution] {
        switch storage { case .spatial(let owner): return owner.input.generalizedForces; case .planar(let owner): return owner.input.generalizedForces }
    }
    @inline(never)
    internal func properties(at index:Int) throws(DynamicsError) -> RigidBodyPhysicalProperties {
        switch storage {
        case .spatial(let owner):
            let properties=owner.input.inertias[index].properties
            return RigidBodyPhysicalProperties(mass:properties.mass,center:properties.centerOfMass,inertia:.spatial(properties.inertiaAtCenter))
        case .planar(let owner):
            let properties=owner.input.inertias[index].properties
            let center=try DynamicsArithmetic.core { () throws(CoreError) in try Vector3(properties.centerX,properties.centerY,0) }
            return RigidBodyPhysicalProperties(mass:properties.mass,center:center,inertia:.planar(properties.polarInertiaAtCenter))
        }
    }
    internal var inertiaCount: Int {
        switch storage { case .spatial(let owner): return owner.input.inertias.count; case .planar(let owner): return owner.input.inertias.count }
    }
    internal func body(at index: Int) -> EntityID {
        switch storage { case .spatial(let owner): return owner.input.inertias[index].body; case .planar(let owner): return owner.input.inertias[index].body }
    }
    internal func frame(at index: Int) -> EntityID {
        switch storage { case .spatial(let owner): return owner.input.inertias[index].frame; case .planar(let owner): return owner.input.inertias[index].frame }
    }
}
