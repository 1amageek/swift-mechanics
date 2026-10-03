import MechanicsNumerics
public struct ReferenceViscousChannelSolver: FluidEvolving, Sendable {
    public let linear: any LinearSolving<Double>
    public let fields: any FluidFieldBuilding
    public init(linear: any LinearSolving<Double>, fields: any FluidFieldBuilding) { self.linear=linear; self.fields=fields }
    public func steady(state: FluidState, boundary: FluidBoundary, policy: FluidPolicy,
                       work: inout NumericalWork) throws(FluidError) -> FluidEvolution {
        try solve(state:state,boundary:boundary,duration:nil,policy:policy,work:&work)
    }
    public func step(state: FluidState, boundary: FluidBoundary, duration: Double, policy: FluidPolicy,
                     work: inout NumericalWork) throws(FluidError) -> FluidEvolution {
        guard duration.isFinite, duration > 0, duration <= state.channel.limits.maximumStep else { throw .domain }
        guard state.sequence < UInt64.max else { throw .capacity }
        let time=try fluidFinite(state.time+duration); guard time > state.time else { throw .domain }
        return try solve(state:state,boundary:boundary,duration:duration,policy:policy,work:&work)
    }
    private func solve(state: FluidState, boundary: FluidBoundary, duration: Double?, policy: FluidPolicy,
                       work: inout NumericalWork) throws(FluidError) -> FluidEvolution {
        try policy.poll(); try state.validate(); try boundary.validate(channel:state.channel)
        let c=state.channel,n=c.cells,g=c.conductance,m=c.cellMass
        let square=try fluidNumerics { () throws(NumericalError) in try NumericalWork.product(n,n) }
        // Reserve old/new u, old/new p, matrix, RHS and face stresses concurrently; supplier work is additive.
        let reserved=try fluidNumerics { () throws(NumericalError) in try NumericalWork.sum(square,try NumericalWork.sum(try NumericalWork.product(7,n),3)) }
        try fluidNumerics { () throws(NumericalError) in try work.requireStorage(reserved) }
        let inertial:Double
        if let dt=duration { inertial=try fluidFinite(m/dt); guard inertial > 0 else { throw .nonfinite } } else { inertial=0 }
        let source=try fluidFinite(-boundary.pressureGradientX+c.density*c.accelerationX)
        let cellForce=try fluidFinite(c.wallArea*c.spacing*source)
        var matrix=[Double](repeating:0,count:square), rhs=[Double](repeating:0,count:n)
        for i in 0..<n {
            try policy.poll(); try fluidNumerics { () throws(NumericalError) in try work.chargeOperations(10) }
            matrix[i*n+i]=try fluidFinite(inertial+(n == 1 ? 4 : (i == 0 || i == n-1 ? 3 : 2))*g)
            if i > 0 { matrix[i*n+i-1] = -g }; if i+1 < n { matrix[i*n+i+1] = -g }
            rhs[i]=try fluidFinite(inertial*state.velocities[i]+cellForce)
            if i == 0 { rhs[i]=try fluidFinite(rhs[i]+2*g*boundary.lowerSpeed) }
            if i == n-1 { rhs[i]=try fluidFinite(rhs[i]+2*g*boundary.upperSpeed) }
        }
        let dense=try fluidNumerics { () throws(NumericalError) in try DenseMatrix(rows:n,columns:n,values:matrix) }
        let remaining=try fluidNumerics { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserved) }
        let solution:LinearSolution<Double>
        do throws(NumericalError) {
            solution=try linear.solve(dense,rightHandSide:rhs,capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),tolerance:policy.linearTolerance,budget:remaining)
        } catch { throw .numerical(error,failedSupplierWorkUnavailable:true) }
        try fluidNumerics { () throws(NumericalError) in try work.absorb(solution.diagnostics.work,reservedStorage:reserved) }
        try policy.poll()
        let pressure=try fields.hydrostatic(channel:c,boundary:boundary,policy:policy,work:&work)
        let candidateTime:Double,candidateSequence:UInt64
        if let dt=duration { candidateTime=state.time+dt; candidateSequence=state.sequence+1 }
        else { candidateTime=state.time; candidateSequence=state.sequence }
        let candidate=FluidState(channel:c,boundary:boundary,time:candidateTime,
                                 sequence:candidateSequence,
                                 velocities:solution.values,pressureFaces:pressure)
        try candidate.validate()
        let balance=try verify(old:state,new:candidate,duration:duration,policy:policy,work:&work)
        try policy.poll(); return FluidEvolution(state:candidate,balance:balance)
    }
    private func verify(old: FluidState, new: FluidState, duration: Double?, policy: FluidPolicy,
                        work: inout NumericalWork) throws(FluidError) -> FluidBalance {
        let c=new.channel,n=c.cells,g=c.conductance,m=c.cellMass,u=new.velocities,b=new.boundary
        let source=try fluidFinite(-b.pressureGradientX+c.density*c.accelerationX)
        let cellForce=try fluidFinite(c.wallArea*c.spacing*source)
        var face=[Double](repeating:0,count:n+1)
        face[0]=try fluidFinite(2*g*(u[0]-b.lowerSpeed)); face[n]=try fluidFinite(2*g*(b.upperSpeed-u[n-1]))
        var dissipation=try fluidFinite(2*g*((u[0]-b.lowerSpeed)*(u[0]-b.lowerSpeed)+(b.upperSpeed-u[n-1])*(b.upperSpeed-u[n-1])))
        if n > 1 { for j in 1..<n { try policy.poll(); try fluidNumerics { () throws(NumericalError) in try work.chargeOperations(6) }
            let delta=u[j]-u[j-1]; face[j]=try fluidFinite(g*delta); dissipation=try fluidFinite(dissipation+g*delta*delta)
        } }
        var maxResidual=0.0, pressureResidual=0.0, kinetic=0.0, oldKinetic=0.0, numerical=0.0, power=0.0
        for i in 0..<n {
            try policy.poll(); try fluidNumerics { () throws(NumericalError) in try work.chargeOperations(32) }
            let accelerationForce:Double
            if let dt=duration { accelerationForce=try fluidFinite(m*(u[i]-old.velocities[i])/dt) } else { accelerationForce=0 }
            let flux=try fluidFinite(face[i+1]-face[i]); let residual=try fluidFinite(accelerationForce-flux-cellForce)
            let scale=max(abs(accelerationForce),abs(face[i+1])+abs(face[i])+abs(cellForce))
            let allowed=try fluidFinite(policy.forceAbsolute+policy.forceRelative*scale)
            guard abs(residual) <= allowed else { throw .originalResidual }; maxResidual=max(maxResidual,abs(residual))
            let pr=try fluidFinite((new.pressureFaces[i+1]-new.pressureFaces[i])/c.spacing-c.density*c.accelerationY)
            guard abs(pr) <= policy.pressureGradientAbsolute else { throw .originalResidual }; pressureResidual=max(pressureResidual,abs(pr))
            kinetic=try fluidFinite(kinetic+0.5*m*u[i]*u[i]); oldKinetic=try fluidFinite(oldKinetic+0.5*m*old.velocities[i]*old.velocities[i])
            let delta=u[i]-old.velocities[i]; numerical=try fluidFinite(numerical+0.5*m*delta*delta)
            power=try fluidFinite(power+cellForce*u[i])
        }
        let boundaryPower=try fluidFinite(face[n]*b.upperSpeed-face[0]*b.lowerSpeed)
        let defect:Double, energyScale:Double
        if let dt=duration {
            defect=try fluidFinite(kinetic-oldKinetic+dt*dissipation+numerical-dt*(power+boundaryPower))
            energyScale=max(abs(kinetic-oldKinetic),max(dt*dissipation+numerical,dt*(abs(power)+abs(boundaryPower))))
        } else {
            numerical=0; defect=try fluidFinite(dissipation-power-boundaryPower)
            energyScale=max(dissipation,abs(power)+abs(boundaryPower))
        }
        let allowed:Double
        if duration != nil { allowed=try fluidFinite(policy.energyAbsolute+policy.energyRelative*energyScale) }
        else { allowed=try fluidFinite(policy.powerAbsolute+policy.powerRelative*energyScale) }
        guard abs(defect) <= allowed else { throw .originalResidual }
        return FluidBalance(maximumMomentumResidual:maxResidual,maximumPressureGradientResidual:pressureResidual,
            kineticEnergy:kinetic,viscousPower:dissipation,sourcePower:power,boundaryPower:boundaryPower,
            numericalDissipation:numerical,energyDefect:duration == nil ? nil : defect,powerDefect:duration == nil ? defect : nil)
    }
}
