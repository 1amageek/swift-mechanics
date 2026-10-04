
public struct PassiveTransmissionEvaluator: TransmissionConstitutiveEvaluating {
    private let passive: any ScalarJointPortEvaluating
    private let mapper: any TransmissionPortMapping
    public init(passive: any ScalarJointPortEvaluating = ScalarJointPortEvaluator(), mapper: any TransmissionPortMapping = AxialTransmissionMapper()) { self.passive=passive; self.mapper=mapper }
    @inline(never)
    public func shaft(_ binding: TransmissionPortBinding,layout: ConstraintCoordinateLayout,position: Double,velocity: Double,acceleration: Double,law: ShaftLaw,
                      policy: TransmissionPolicy,work: inout NumericalWork,constraintWork: inout NumericalWork) throws(TransmissionError) -> ShaftResponse {
        // A fixed single-port owner is admitted before allocating its one-record view.
        try TransmissionArithmetic.storage(64,&work)
        try TransmissionArithmetic.validate([binding],layout:layout,policy:policy,work:&work)
        guard binding.manifold.kind == .revolute, acceleration.isFinite else { throw .invalidInput }
        let response: ScalarJointResponse
        do { response=try passive.passive(binding.manifold,position:position,velocity:velocity,law:law.passive,wrap:.unwrapped,
            policy:ConstraintEvaluationPolicy(maximumCoordinates:policy.maximumCoordinates,maximumRows:policy.maximumRelations,expectedLayoutRevision:policy.expectedLayoutRevision,isCancelled:policy.isCancelled),work:&constraintWork) } catch { throw .constraint(error) }
        try TransmissionArithmetic.charge(6,&work)
        guard response.smoothEffort.isFinite, response.potentialEnergy.isFinite, response.damperPower.isFinite else { throw .nonFiniteResult }
        guard case .disabled = response.friction else { throw .invalidInput }
        let inertia=try TransmissionArithmetic.finite(law.rotationalInertia*acceleration), kinetic=try TransmissionArithmetic.finite(0.5*law.rotationalInertia*velocity*velocity)
        let axis=try TransmissionArithmetic.axis(binding,&work), torque: Vector3
        try TransmissionArithmetic.charge(1,&work)
        do { torque=try axis.scaled(by:response.smoothEffort) } catch { throw .core(error) }
        try TransmissionArithmetic.check(policy)
        return ShaftResponse(binding:binding,inertiaCoefficient:law.rotationalInertia,requiredInertialEffort:inertia,kineticEnergy:kinetic,passive:response,passiveAxialTorque:torque)
    }
    @inline(never)
    public func initializeBacklash(_ network: CompiledTransmissionNetwork,rowIndex: Int,position: [Double],time: Double,law: BacklashLaw,
                                   policy: TransmissionPolicy,work: inout NumericalWork) throws(TransmissionError) -> BacklashContinuation {
        let phase=try phaseInput(network,rowIndex:rowIndex,position:position,time:time,policy:policy,work:&work)
        let state=try elastic(phase,law:law,work:&work)
        try TransmissionArithmetic.storage(24,&work); try TransmissionArithmetic.check(policy)
        return continuation(network,row:network.physicalRows[rowIndex],time:time,phase:phase,energy:state.energy,branch:state.branch,law:law)
    }
    @inline(never)
    public func backlash(_ network: CompiledTransmissionNetwork,rowIndex: Int,position: [Double],velocity: [Double],time: Double,law: BacklashLaw,accepted: BacklashContinuation,
                         policy: TransmissionPolicy,work: inout NumericalWork) throws(TransmissionError) -> BacklashResponse {
        let phase=try phaseInput(network,rowIndex:rowIndex,position:position,time:time,policy:policy,work:&work), row=network.physicalRows[rowIndex]
        try validateAccepted(accepted,network:network,row:row,time:time,law:law,policy:policy,work:&work)
        let n=network.equations.layout.scales.count
        guard velocity.count == n else { throw .invalidDimensions }
        try TransmissionArithmetic.storage(TransmissionArithmetic.sum(n,TransmissionArithmetic.sum(TransmissionArithmetic.product(64,network.ports.count),24)),&work)
        var rate=0.0, efforts=[Double](repeating:0,count:n)
        for i in 0..<n { try TransmissionArithmetic.charge(3,&work); guard velocity[i].isFinite else { throw .invalidInput }; rate=try TransmissionArithmetic.finite(rate+row.coefficients[i]*velocity[i]) }
        let state=try elastic(phase,law:law,work:&work)
        try TransmissionArithmetic.charge(9,&work)
        let closing=(phase > law.halfClearance && rate > 0) || (phase < -law.halfClearance && rate < 0)
        let damping=closing ? -law.damping*rate : 0
        let phaseEffort=try TransmissionArithmetic.finite(-law.stiffness*state.deflection+damping)
        let loss=try TransmissionArithmetic.finite(damping*rate), potentialRate=try TransmissionArithmetic.finite(law.stiffness*state.deflection*rate)
        for i in 0..<n { try TransmissionArithmetic.charge(1,&work); efforts[i]=try TransmissionArithmetic.finite(phaseEffort*row.coefficients[i]) }
        let mapped=try mapper.map(network.ports,layout:network.equations.layout,efforts:efforts,velocity:velocity,policy:policy,work:&work)
        try TransmissionArithmetic.charge(6,&work)
        let residual=try TransmissionArithmetic.finite(max(abs(mapped.totalPower-phaseEffort*rate),abs(mapped.totalPower+potentialRate-loss))/policy.powerScale)
        guard loss <= 0, residual <= policy.powerTolerance else { throw .powerResidual(value:residual) }
        try TransmissionArithmetic.check(policy)
        return BacklashResponse(phaseEffort:phaseEffort,potentialEnergy:state.energy,potentialRate:potentialRate,dissipativePower:loss,mapped:mapped,originalPowerResidual:residual,
            trial:continuation(network,row:row,time:time,phase:phase,energy:state.energy,branch:state.branch,law:law))
    }
    @inline(never)
    public func drag(_ binding: TransmissionPortBinding,layout: ConstraintCoordinateLayout,velocity: Double,law: DirectionalDragLaw,
                     policy: TransmissionPolicy,work: inout NumericalWork) throws(TransmissionError) -> DirectionalDragResponse {
        try TransmissionArithmetic.storage(64,&work); try TransmissionArithmetic.validate([binding],layout:layout,policy:policy,work:&work)
        guard velocity.isFinite, abs(velocity) <= law.maximumAbsVelocity else { throw .outsideDomain }
        try TransmissionArithmetic.charge(8,&work)
        let c=velocity >= 0 ? law.positiveViscous : law.negativeViscous, f=velocity >= 0 ? law.positiveCoulomb : law.negativeCoulomb
        let viscous=try TransmissionArithmetic.finite(-c*velocity), friction: JointFrictionResponse, selected: Double?, loss: Double
        if velocity == 0, law.positiveCoulomb > 0 || law.negativeCoulomb > 0 {
            friction = .staticInterval(lowerEffort:-law.positiveCoulomb,upperEffort:law.negativeCoulomb); selected=nil; loss=0
        } else {
            let dry=velocity > 0 ? -f : (velocity < 0 ? f : 0)
            loss=try TransmissionArithmetic.finite((viscous+dry)*velocity); selected=try TransmissionArithmetic.finite(viscous+dry)
            friction=f == 0 ? .disabled : .sliding(effort:dry,dissipativePower:try TransmissionArithmetic.finite(dry*velocity))
        }
        guard loss <= 0 else { throw .powerResidual(value:loss) }; try TransmissionArithmetic.check(policy)
        return DirectionalDragResponse(binding:binding,viscousEffort:viscous,dryFriction:friction,selectedEffort:selected,dissipativePower:loss)
    }
    @inline(never)
    private func phaseInput(_ network: CompiledTransmissionNetwork,rowIndex: Int,position: [Double],time: Double,policy: TransmissionPolicy,work: inout NumericalWork) throws(TransmissionError) -> Double {
        try TransmissionArithmetic.validate(network.ports,layout:network.equations.layout,policy:policy,work:&work)
        guard network.modelRevision == policy.expectedModelRevision, network.physicalRows.count <= policy.maximumRelations else { throw .staleBinding }
        guard rowIndex >= 0, rowIndex < network.physicalRows.count, position.count == network.equations.layout.scales.count else { throw .invalidDimensions }
        guard time.isFinite, time >= network.equations.minimumTime, time <= network.equations.maximumTime else { throw .outsideDomain }
        let row=network.physicalRows[rowIndex]; var phase = -row.phase
        for i in position.indices {
            try TransmissionArithmetic.check(policy); try TransmissionArithmetic.charge(5,&work)
            guard position[i].isFinite, position[i] >= network.equations.minimumPosition[i], position[i] <= network.equations.maximumPosition[i] else { throw .outsideDomain }
            phase=try TransmissionArithmetic.finite(phase+row.coefficients[i]*position[i])
        }
        return phase
    }
    private func elastic(_ phase: Double,law: BacklashLaw,work: inout NumericalWork) throws(TransmissionError) -> (deflection: Double,energy: Double,branch: BacklashBranch) {
        guard phase.isFinite, abs(phase) <= law.maximumAbsPhase else { throw .outsideDomain }
        try TransmissionArithmetic.charge(6,&work)
        let z: Double, branch: BacklashBranch
        if phase > law.halfClearance { z=phase-law.halfClearance; branch = .positiveFlank }
        else if phase < -law.halfClearance { z=phase+law.halfClearance; branch = .negativeFlank }
        else { z=0; branch = .free }
        return (z,try TransmissionArithmetic.finite(0.5*law.stiffness*z*z),branch)
    }
    private func validateAccepted(_ state: BacklashContinuation,network: CompiledTransmissionNetwork,row: PhysicalTransmissionRow,time: Double,law: BacklashLaw,
                                  policy: TransmissionPolicy,work: inout NumericalWork) throws(TransmissionError) {
        try TransmissionArithmetic.charge(12,&work)
        guard state.networkID == network.id, state.rowID == row.id, state.layoutRevision == policy.expectedLayoutRevision,
              state.modelRevision == policy.expectedModelRevision, state.lawID == law.id, state.lawRevision == law.revision,
              state.time.isFinite, state.time >= network.equations.minimumTime, state.time <= time, state.storedEnergy.isFinite else { throw .staleContinuation }
        let expected=try elastic(state.phase,law:law,work:&work)
        guard expected.branch == state.branch, abs(expected.energy-state.storedEnergy)/law.energyScale <= policy.originalTolerance else { throw .staleContinuation }
    }
    private func continuation(_ network: CompiledTransmissionNetwork,row: PhysicalTransmissionRow,time: Double,phase: Double,energy: Double,branch: BacklashBranch,law: BacklashLaw) -> BacklashContinuation {
        BacklashContinuation(networkID:network.id,rowID:row.id,layoutRevision:network.equations.layout.revision,modelRevision:network.modelRevision,
            lawID:law.id,lawRevision:law.revision,time:time,phase:phase,storedEnergy:energy,branch:branch)
    }
}
