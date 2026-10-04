
public struct AxialTransmissionMapper: TransmissionPortMapping {
    public init() {}
    @inline(never)
    public func map(_ ports: [TransmissionPortBinding],layout: ConstraintCoordinateLayout,efforts: [Double],velocity: [Double],policy: TransmissionPolicy,work: inout NumericalWork) throws(TransmissionError) -> MappedTransmissionPorts {
        try TransmissionArithmetic.validate(ports,layout:layout,policy:policy,work:&work)
        let n=layout.scales.count
        guard efforts.count == n, velocity.count == n else { throw .invalidDimensions }
        try TransmissionArithmetic.storage(TransmissionArithmetic.product(64,ports.count),&work)
        for i in 0..<n {
            try TransmissionArithmetic.check(policy); try TransmissionArithmetic.charge(2,&work)
            guard efforts[i].isFinite, velocity[i].isFinite else { throw .invalidInput }
            var bound=false
            for port in ports { try TransmissionArithmetic.charge(1,&work); if port.coordinateIndex == i { bound=true } }
            guard bound || efforts[i] == 0 else { throw .invalidInput }
        }
        var result: [TransmissionPortEffort]=[]; result.reserveCapacity(ports.count); var power=0.0
        for port in ports {
            try TransmissionArithmetic.check(policy)
            let axis=try TransmissionArithmetic.axis(port,&work), i=port.coordinateIndex
            guard i < efforts.count, i < velocity.count else { throw .invalidDimensions }
            try TransmissionArithmetic.charge(2,&work)
            let product=try TransmissionArithmetic.finite(efforts[i]*velocity[i]); power=try TransmissionArithmetic.finite(power+product)
            let wrench: SpatialWrench
            try TransmissionArithmetic.charge(port.manifold.kind == .revolute ? 1 : 2,&work)
            do {
                if port.manifold.kind == .revolute { wrench=SpatialWrench(torque:try axis.scaled(by:efforts[i]),force:.zero) }
                else {
                    let force=try axis.scaled(by:efforts[i]); wrench=SpatialWrench(torque:try port.jointToReference.translation.cross(force),force:force)
                }
            } catch { throw .core(error) }
            result.append(TransmissionPortEffort(binding:port,axisInReference:axis,generalizedEffort:efforts[i],power:product,wrenchAboutReferenceOrigin:wrench))
        }
        try TransmissionArithmetic.check(policy)
        return MappedTransmissionPorts(ports:result,totalPower:power)
    }
}
