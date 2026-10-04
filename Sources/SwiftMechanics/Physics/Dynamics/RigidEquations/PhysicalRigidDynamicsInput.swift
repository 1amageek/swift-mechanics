/// Immutable original source. The inactive dimension has no substitute inertia inventory.
public final class PhysicalRigidDynamicsInput: Sendable {
    public enum Source: Sendable {
        case spatial(RigidDynamicsInput)
        case planar(PlanarRigidDynamicsInput)
    }
    public let source: Source
    public init(spatial: RigidDynamicsInput) { source = .spatial(spatial) }
    public init(planar: PlanarRigidDynamicsInput) { source = .planar(planar) }
    public var dimension: KinematicDimension {
        switch source { case .spatial: return .spatial; case .planar: return .planar }
    }
    public var snapshot: KinematicSnapshot {
        switch source { case .spatial(let input): return input.snapshot; case .planar(let input): return input.snapshot }
    }
    public var velocity: [Double] {
        switch source { case .spatial(let input): return input.velocity; case .planar(let input): return input.velocity }
    }
    public var gravity: AffineGravity? {
        switch source { case .spatial(let input): return input.gravity; case .planar(let input): return input.gravity }
    }
    public var bodyWrenches: [BodyWrenchContribution] {
        switch source { case .spatial(let input): return input.bodyWrenches; case .planar(let input): return input.bodyWrenches }
    }
    public var generalizedForces: [GeneralizedForceContribution] {
        switch source { case .spatial(let input): return input.generalizedForces; case .planar(let input): return input.generalizedForces }
    }
    @inline(never)
    internal func properties(at index:Int) throws(DynamicsError) -> RigidBodyPhysicalProperties {
        switch source {
        case .spatial(let input):
            let properties=input.inertias[index].properties
            return RigidBodyPhysicalProperties(mass:properties.mass,center:properties.centerOfMass,inertia:.spatial(properties.inertiaAtCenter))
        case .planar(let input):
            let properties=input.inertias[index].properties
            let center=try DynamicsArithmetic.core { () throws(CoreError) in try Vector3(properties.centerX,properties.centerY,0) }
            return RigidBodyPhysicalProperties(mass:properties.mass,center:center,inertia:.planar(properties.polarInertiaAtCenter))
        }
    }
    internal var inertiaCount: Int {
        switch source { case .spatial(let input): return input.inertias.count; case .planar(let input): return input.inertias.count }
    }
    internal func body(at index: Int) -> EntityID {
        switch source { case .spatial(let input): return input.inertias[index].body; case .planar(let input): return input.inertias[index].body }
    }
    internal func frame(at index: Int) -> EntityID {
        switch source { case .spatial(let input): return input.inertias[index].frame; case .planar(let input): return input.inertias[index].frame }
    }
}
