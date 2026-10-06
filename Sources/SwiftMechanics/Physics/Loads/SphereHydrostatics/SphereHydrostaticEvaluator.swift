public struct SphereHydrostaticEvaluator: SphereHydrostaticEvaluating {
    public init() {}
    public func evaluate(_ law: SphereHydrostaticLaw, body: EntityID, frame: EntityID, center: Vector3,
                         planePoint: Vector3, upwardNormal: Vector3, work: inout LoadWork) throws(LoadError) -> SphereHydrostaticResponse {
        try work.charge(200); try work.reserve(scalars: 64)
        let n = try core { () throws(CoreError) in try upwardNormal.normalized() }
        let d = try core { () throws(CoreError) in try center.subtracting(planePoint).dot(n) }
        let r = law.radius, scale = try finite(law.density * law.gravitationalAcceleration)
        let fullVolume = try finite(4 * Double.pi / 3 * r * r * r)
        let volume: Double, offset: Double, area: Double, energy: Double
        if d >= r {
            volume = 0; offset = 0; area = 0; energy = 0
        } else if d <= -r {
            volume = fullVolume; offset = 0; area = 0; energy = try finite(-scale * volume * d)
        } else {
            let t = try finite(1 - d / r)
            volume = try finite(Double.pi * r * r * r * t * t * (1 - t / 3))
            // A vanishing cap cannot publish a centroid of numerically zero volume.
            guard volume > 0 else { throw .outsideDomain }
            offset = try finite(-r * (2 - t) * (2 - t) / (4 * (1 - t / 3)))
            area = try finite(Double.pi * r * r * t * (2 - t))
            energy = try finite(scale * Double.pi / 12 * r * r * r * r * t * t * t * (4 - t))
        }
        let centroid = volume > 0 ? try core { () throws(CoreError) in try center.adding(n.scaled(by: offset)) } : nil
        let magnitude = try finite(scale * volume)
        let force = try core { () throws(CoreError) in try n.scaled(by: magnitude) }
        let k = try finite(-scale * area)
        let derivative = try core { () throws(CoreError) in try Matrix3(k*n.x*n.x,k*n.x*n.y,k*n.x*n.z,
            k*n.y*n.x,k*n.y*n.y,k*n.y*n.z,k*n.z*n.x,k*n.z*n.y,k*n.z*n.z) }
        let load = try FramedPointLoad(body: body, frame: frame, point: centroid ?? center,
                                      forces: ForceParts(conservative: force), potentialEnergy: energy)
        try work.charge(0)
        return SphereHydrostaticResponse(load: load, displacedVolume: volume, centerOfBuoyancy: centroid,
                                         waterplaneArea: area, forcePositionDerivative: derivative)
    }

    private func core<T>(_ operation: () throws(CoreError) -> T) throws(LoadError) -> T {
        do { return try operation() } catch { throw .core(error) }
    }
    private func finite(_ value: Double) throws(LoadError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
}
