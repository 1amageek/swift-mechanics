import MechanicsCore
import MechanicsModel
public struct FluidLoadEvaluator: FluidLoadEvaluating {
    public init() {}
    /// One supplied application center is admitted. Separate drag/buoyancy centers require separate calls.
    public func evaluate(_ law: LumpedFluidLaw, medium: LumpedMedium, body: EntityID, frame: EntityID,
                         centerOfBuoyancyAndDrag point: Vector3, velocity: Vector3, work: inout LoadWork) throws(LoadError) -> FluidLoadResponse {
        try work.charge(1)
        let relative = try loadCore { () throws(CoreError) in try velocity.subtracting(medium.velocity) }
        let speed = try loadCore { () throws(CoreError) in try relative.magnitude() }
        guard speed <= law.maximumRelativeSpeed else { throw .outsideDomain }
        let coefficient = try loadFinite(law.linearDrag + law.quadraticDrag * speed)
        let drag = try loadCore { () throws(CoreError) in try relative.scaled(by: -coefficient) }
        let displacedMass = try loadFinite(medium.density * law.displacedVolume)
        let buoyancy = try loadCore { () throws(CoreError) in try medium.gravity.scaled(by: -displacedMass) }
        let potential = try loadFinite(displacedMass * loadCore { () throws(CoreError) in try medium.gravity.dot(point) })
        let unit = speed > 0 ? try loadCore { () throws(CoreError) in try relative.normalized() } : .zero
        let d = -coefficient, q = -law.quadraticDrag * speed
        let derivative = try loadCore { () throws(CoreError) in try Matrix3(d + q * unit.x * unit.x, q * unit.x * unit.y, q * unit.x * unit.z,
            q * unit.y * unit.x, d + q * unit.y * unit.y, q * unit.y * unit.z,
            q * unit.z * unit.x, q * unit.z * unit.y, d + q * unit.z * unit.z) }
        return try FluidLoadResponse(load: FramedPointLoad(body: body, frame: frame, point: point,
            forces: ForceParts(conservative: buoyancy, dissipative: drag), potentialEnergy: potential),
            forceVelocityDerivative: derivative,
            relativeDissipatedPower: loadFinite(-loadCore { () throws(CoreError) in try drag.dot(relative) }),
            prescribedMediumPower: loadCore { () throws(CoreError) in try drag.dot(medium.velocity) })
    }
}
