public struct LoadMapper: LoadMapping {
    public init() {}
    public func point(_ load: FramedPointLoad, jacobian: PointJacobian, rate: [Double], work: inout LoadWork) throws(LoadError) -> GeneralizedLoad {
        guard load.body == jacobian.body, load.frame == jacobian.referenceFrame, load.point == jacobian.pointWorld else { throw .frameMismatch }
        guard rate.count == jacobian.columns.count, rate.allSatisfy({ $0.isFinite }) else { throw .invalidShape }
        try work.reserve(scalars: rate.count)
        let total = try load.forces.total()
        var values = [Double](repeating: 0, count: rate.count), virtualVelocity = Vector3.zero
        for index in rate.indices {
            try work.charge(1)
            values[index] = try loadCore { () throws(CoreError) in try total.dot(jacobian.columns[index]) }
            virtualVelocity = try loadCore { () throws(CoreError) in try virtualVelocity.adding(jacobian.columns[index].scaled(by: rate[index])) }
        }
        try work.charge(1)
        let actualVelocity = try loadCore { () throws(CoreError) in try virtualVelocity.adding(jacobian.prescribedDriftVelocity) }
        let power = try loadCore { () throws(CoreError) in try LoadPower(virtual: total.dot(virtualVelocity), prescribedDrift: total.dot(jacobian.prescribedDriftVelocity),
            actual: total.dot(actualVelocity), conservativeActual: load.forces.conservative.dot(actualVelocity),
            dissipativeActual: load.forces.dissipative.dot(actualVelocity), activeActual: load.forces.active.dot(actualVelocity)) }
        return GeneralizedLoad(values: values, power: power)
    }
    /// Caller supplies a wrench with exactly the Jacobian's declared torque reference.
    public func wrench(_ wrench: SpatialWrench, load: FramedPointLoad, jacobian: KinematicJacobian,
                       rate: [Double], work: inout LoadWork) throws(LoadError) -> [Double] {
        guard load.body == jacobian.body, load.frame == jacobian.referenceFrame else { throw .frameMismatch }
        // Verify the supplied wrench rather than infer its origin from its numeric components.
        guard wrench == (try load.wrench(about: jacobian.referencePointWorld)) else { throw .frameMismatch }
        guard rate.count == jacobian.columns.count, rate.allSatisfy({ $0.isFinite }) else { throw .invalidShape }
        return try transpose(wrench, columns: jacobian.columns, work: &work)
    }
    public func impulse(_ impulse: FramedImpulse, jacobian: KinematicJacobian, work: inout LoadWork) throws(LoadError) -> [Double] {
        guard impulse.body == jacobian.body, impulse.frame == jacobian.referenceFrame else { throw .frameMismatch }
        return try transpose(impulse.equivalent(about: jacobian.referencePointWorld), columns: jacobian.columns, work: &work)
    }
    private func transpose(_ wrench: SpatialWrench, columns: [SpatialMotion], work: inout LoadWork) throws(LoadError) -> [Double] {
        try work.reserve(scalars: columns.count)
        var result = [Double](repeating: 0, count: columns.count)
        for index in columns.indices { try work.charge(1); result[index] = try loadCore { () throws(CoreError) in try wrench.power(against: columns[index]) } }
        return result
    }
}
