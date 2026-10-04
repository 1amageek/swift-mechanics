public struct ReferenceFluidFieldBuilder: FluidFieldBuilding, Sendable {
    public init() {}
    public func makeState(channel: FluidChannel, boundary: FluidBoundary, time: Double, velocities: [Double],
                          policy: FluidPolicy, work: inout NumericalWork) throws(FluidError) -> FluidState {
        guard velocities.count == channel.cells else { throw .invalidInput }
        try fluidNumerics { () throws(NumericalError) in try work.requireStorage(try NumericalWork.sum(velocities.count,channel.cells+1)) }
        let pressures=try hydrostatic(channel:channel,boundary:boundary,policy:policy,work:&work)
        let state=FluidState(channel:channel,boundary:boundary,time:time,sequence:0,velocities:velocities,pressureFaces:pressures)
        try state.validate(); try policy.poll(); return state
    }
    public func hydrostatic(channel: FluidChannel, boundary: FluidBoundary, policy: FluidPolicy,
                            work: inout NumericalWork) throws(FluidError) -> [Double] {
        try policy.poll(); try boundary.validate(channel:channel)
        try fluidNumerics { () throws(NumericalError) in try work.requireStorage(try NumericalWork.sum(channel.cells,1)) }
        let gradient=try fluidFinite(channel.density*channel.accelerationY)
        let delta=try fluidFinite(gradient*channel.spacing)
        var pressures=[Double](repeating:0,count:channel.cells+1); pressures[0]=boundary.lowerGaugePressure
        for i in 0..<channel.cells {
            try policy.poll(); try fluidNumerics { () throws(NumericalError) in try work.chargeOperations(5) }
            pressures[i+1]=try fluidFinite(pressures[i]+delta)
            guard abs(pressures[i+1]) <= channel.limits.maximumPressure else { throw .domain }
            let residual=try fluidFinite((pressures[i+1]-pressures[i])/channel.spacing-gradient)
            guard abs(residual) <= policy.pressureGradientAbsolute else { throw .originalResidual }
        }
        try policy.poll(); return pressures
    }
}
