public struct TrianglePressureEvaluator: TrianglePressureEvaluating {
    public init() {}
    public func evaluate(pressure: Double, body: EntityID, frame: EntityID, vertices: [Vector3], velocities: [Vector3],
                         referencePoint: Vector3, minimumTwiceArea: Double, work: inout LoadWork) throws(LoadError) -> TrianglePressureResponse {
        try work.charge(300); try work.reserve(scalars: 128)
        guard pressure.isFinite, pressure >= 0, minimumTwiceArea.isFinite, minimumTwiceArea >= 0,
              vertices.count == 3, velocities.count == 3 else { throw .invalidInput }
        let e1 = try core { () throws(CoreError) in try vertices[1].subtracting(vertices[0]) }
        let e2 = try core { () throws(CoreError) in try vertices[2].subtracting(vertices[0]) }
        let areaVector = try core { () throws(CoreError) in try e1.cross(e2) }
        let area = try core { () throws(CoreError) in try areaVector.magnitude() }
        guard area > minimumTwiceArea else { throw .invalidShape }
        let factor = -pressure / 6
        let force = try core { () throws(CoreError) in try areaVector.scaled(by: factor) }
        let da = try core { () throws(CoreError) in try skew(e2.subtracting(e1)).scaled(by: factor) }
        let db = try core { () throws(CoreError) in try skew(e2).scaled(by: -factor) }
        let dc = try core { () throws(CoreError) in try skew(e1).scaled(by: factor) }
        var loads: [FramedPointLoad] = []; loads.reserveCapacity(3)
        var totalForce = Vector3.zero, torque = Vector3.zero, power = 0.0
        for i in 0..<3 {
            let load = try FramedPointLoad(body: body, frame: frame, point: vertices[i], forces: ForceParts(active: force))
            let wrench = try load.wrench(about: referencePoint)
            totalForce = try core { () throws(CoreError) in try totalForce.adding(wrench.force) }
            torque = try core { () throws(CoreError) in try torque.adding(wrench.torque) }
            power = try finite(power + core { () throws(CoreError) in try force.dot(velocities[i]) })
            loads.append(load)
        }
        try work.charge(0)
        return TrianglePressureResponse(body: body, frame: frame, nodalLoads: loads, forceVertexDerivatives: [da,db,dc],
            resultant: SpatialWrench(torque: torque, force: totalForce), referencePoint: referencePoint, mechanicalPower: power)
    }
    private func skew(_ v: Vector3) throws(CoreError) -> Matrix3 {
        try Matrix3(0,-v.z,v.y,v.z,0,-v.x,-v.y,v.x,0)
    }

    private func core<T>(_ operation: () throws(CoreError) -> T) throws(LoadError) -> T {
        do { return try operation() } catch { throw .core(error) }
    }
    private func finite(_ value: Double) throws(LoadError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
}
