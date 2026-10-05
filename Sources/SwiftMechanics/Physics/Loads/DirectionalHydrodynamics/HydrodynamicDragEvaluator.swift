public struct HydrodynamicDragEvaluator: HydrodynamicDragEvaluating {
    public init() {}
    public func evaluate(_ law: HydrodynamicDragLaw, body: EntityID, frame: EntityID, point: Vector3,
                         longitudinalAxis: Vector3, velocity: Vector3, mediumVelocity: Vector3,
                         work: inout LoadWork) throws(LoadError) -> HydrodynamicDragResponse {
        try work.charge(300); try work.reserve(scalars: 96)
        let axis = try core { () throws(CoreError) in try longitudinalAxis.normalized() }
        let relative = try core { () throws(CoreError) in try velocity.subtracting(mediumVelocity) }
        let speed = try core { () throws(CoreError) in try relative.magnitude() }
        guard speed <= law.maximumRelativeSpeed else { throw .outsideDomain }
        let s = try core { () throws(CoreError) in try relative.dot(axis) }
        let w = try core { () throws(CoreError) in try relative.subtracting(axis.scaled(by: s)) }
        let transverseSpeed = try core { () throws(CoreError) in try w.magnitude() }
        let axialEffort = try finite(-law.axialCoefficient * abs(s) * s)
        let transverseScale = try finite(-law.transverseCoefficient * transverseSpeed)
        let force = try core { () throws(CoreError) in try axis.scaled(by: axialEffort).adding(w.scaled(by: transverseScale)) }
        let loss = try finite(law.axialCoefficient * abs(s) * s * s + law.transverseCoefficient * transverseSpeed * transverseSpeed * transverseSpeed)
        let mediumPower = try core { () throws(CoreError) in try force.dot(mediumVelocity) }
        let axialTangent = try finite(-2 * law.axialCoefficient * abs(s))
        let u = transverseSpeed > 0 ? try core { () throws(CoreError) in try w.scaled(by: 1 / transverseSpeed) } : .zero
        let derivative = try core { () throws(CoreError) in
            try Matrix3(axialTangent*axis.x*axis.x + transverseScale*(1-axis.x*axis.x+u.x*u.x),
                axialTangent*axis.x*axis.y + transverseScale*(-axis.x*axis.y+u.x*u.y),
                axialTangent*axis.x*axis.z + transverseScale*(-axis.x*axis.z+u.x*u.z),
                axialTangent*axis.y*axis.x + transverseScale*(-axis.y*axis.x+u.y*u.x),
                axialTangent*axis.y*axis.y + transverseScale*(1-axis.y*axis.y+u.y*u.y),
                axialTangent*axis.y*axis.z + transverseScale*(-axis.y*axis.z+u.y*u.z),
                axialTangent*axis.z*axis.x + transverseScale*(-axis.z*axis.x+u.z*u.x),
                axialTangent*axis.z*axis.y + transverseScale*(-axis.z*axis.y+u.z*u.y),
                axialTangent*axis.z*axis.z + transverseScale*(1-axis.z*axis.z+u.z*u.z))
        }
        let load = try FramedPointLoad(body: body, frame: frame, point: point, forces: ForceParts(dissipative: force))
        let result = HydrodynamicDragResponse(load: load, forceVelocityDerivative: derivative,
                                          relativeDissipatedPower: loss, prescribedMediumPower: mediumPower)
        try work.charge(0); return result
    }

    private func core<T>(_ operation: () throws(CoreError) -> T) throws(LoadError) -> T {
        do { return try operation() } catch { throw .core(error) }
    }
    private func finite(_ value: Double) throws(LoadError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
}
