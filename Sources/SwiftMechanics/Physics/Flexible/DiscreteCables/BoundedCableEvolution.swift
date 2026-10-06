public struct BoundedCableEvolution: CableEvolving, Sendable {
    public init() {}

    public func evolve(_ cable: DiscreteCable, state: NodalState, loads: CableLoads, duration: Double,
                       policy: CablePolicy, work: inout NumericalWork) -> CableEvolutionResult {
        do { return try run(cable,state: state,loads: loads,duration: duration,policy: policy,work: &work) }
        catch { return .rejected(original: state,reason: error,work: work) }
    }

    private func run(_ cable: DiscreteCable, state: NodalState, loads: CableLoads, duration: Double,
                     policy: CablePolicy, work: inout NumericalWork) throws(CableError) -> CableEvolutionResult {
        try CableArithmetic.check(policy)
        guard duration.isFinite, duration > 0 else { throw .invalidInput }
        guard duration >= policy.minimumSubstep else { throw .minimumSubstep }
        let n = cable.nodes.count
        guard n <= policy.maximumNodes else { throw .capacityExceeded }
        guard loads.nodeIdentifiers.count == n, loads.heldNodalForces.count == n,
              loads.fixedNodes.count == n else { throw .layoutMismatch }
        // Bound load metadata before any frame equality, including an adversarial mismatch.
        var loadBytes = 0
        for _ in loads.frame.key.utf8 {
            try CableArithmetic.check(policy)
            guard loadBytes < policy.maximumMetadataBytes else { throw .capacityExceeded }
            try CableArithmetic.charge(1,&work); loadBytes += 1
        }
        guard loads.frame == cable.frame, loads.revision == cable.revision else { throw .layoutMismatch }
        let service: any CableAssembling = ObjectiveCableAssembler()
        let initialAssembly = try service.assemble(cable,state: state,derivativeOrder: .forceOnly,policy: policy,work: &work)
        for i in 0..<n {
            try CableArithmetic.check(policy); try CableArithmetic.charge(4,&work)
            guard loads.nodeIdentifiers[i] == state.nodeIdentifiers[i] else { throw .layoutMismatch }
            if loads.fixedNodes[i], state.velocities[i] != .zero { throw .invalidInput }
        }
        let initialEnergy = try mechanicalEnergy(state,assembly: initialAssembly,policy: policy,work: &work)
        let initialMomentum = try momentum(state,mass: initialAssembly.lumpedNodeMass,angular: false,policy: policy,work: &work)
        let initialAngular = try momentum(state,mass: initialAssembly.lumpedNodeMass,angular: true,policy: policy,work: &work)
        var current = state, assembly = initialAssembly, elapsed = 0.0, substep = duration
        var currentEnergy = initialEnergy, externalWork = 0.0, dampingLoss = 0.0
        var maximumEnergyResidual = 0.0, maximumMomentumResidual = 0.0, maximumAngularResidual = 0.0
        var appliedImpulse = Vector3.zero, appliedAngularImpulse = Vector3.zero
        var supports = [Vector3](repeating: .zero,count: n)
        var attempts = 0, accepted = 0
        while elapsed < duration {
            try CableArithmetic.check(policy)
            guard attempts < policy.maximumAttempts else { throw .attemptLimit }
            try CableArithmetic.numerical { () throws(NumericalError) in try work.advanceIteration() }
            attempts += 1
            let remaining = try CableArithmetic.finite(duration-elapsed), h = min(substep,remaining)
            guard h >= policy.minimumSubstep else { throw .minimumSubstep }
            let trial: CableTrial
            do {
                trial = try advance(cable,state: current,assembly: assembly,loads: loads,h: h,
                                    oldEnergy: currentEnergy,policy: policy,work: &work)
            } catch {
                guard error == .acceptanceFailed else { throw error }
                let reduced = h*0.5
                guard reduced >= policy.minimumSubstep, reduced < h else { throw .minimumSubstep }
                substep = reduced
                continue
            }
            let nextElapsed = h == remaining ? duration : try CableArithmetic.finite(elapsed+h)
            guard nextElapsed > elapsed else { throw .minimumSubstep }
            current = trial.state; currentEnergy = trial.mechanicalEnergy; elapsed = nextElapsed
            accepted += 1
            try CableArithmetic.charge(try CableArithmetic.product(6,n),&work)
            externalWork = try CableArithmetic.finite(externalWork+trial.externalWork)
            dampingLoss = try CableArithmetic.finite(dampingLoss+trial.dampingWorkLoss)
            appliedImpulse = try CableArithmetic.add(appliedImpulse,trial.appliedImpulse)
            appliedAngularImpulse = try CableArithmetic.add(appliedAngularImpulse,trial.appliedAngularImpulse)
            maximumEnergyResidual = max(maximumEnergyResidual,abs(trial.energyResidual))
            maximumMomentumResidual = max(maximumMomentumResidual,trial.momentumResidual)
            maximumAngularResidual = max(maximumAngularResidual,trial.angularMomentumResidual)
            for i in 0..<n { supports[i] = try CableArithmetic.add(supports[i],trial.supportImpulse[i]) }
            if elapsed < duration {
                assembly = try service.assemble(cable,state: current,derivativeOrder: .forceOnly,policy: policy,work: &work)
                // Avoid an otherwise unrepresentable final remainder without changing duration.
                let rest = duration-elapsed
                if rest > substep, rest-substep < policy.minimumSubstep { substep = rest }
            }
        }
        let residual = try CableArithmetic.finite(currentEnergy-initialEnergy-externalWork+dampingLoss)
        guard try within(abs(residual),absolute: policy.absoluteEnergyTolerance,
                         scale: max(abs(initialEnergy),max(abs(currentEnergy),abs(externalWork)+dampingLoss)),policy: policy) else { throw .acceptanceFailed }
        let finalMomentum = try momentum(current,mass: initialAssembly.lumpedNodeMass,angular: false,policy: policy,work: &work)
        let finalAngular = try momentum(current,mass: initialAssembly.lumpedNodeMass,angular: true,policy: policy,work: &work)
        let globalMomentumResidual = try balance(initialMomentum,finalMomentum,impulse: appliedImpulse,
                                                absolute: policy.absoluteMomentumTolerance,policy: policy)
        let globalAngularResidual = try balance(initialAngular,finalAngular,impulse: appliedAngularImpulse,
                                               absolute: policy.absoluteAngularMomentumTolerance,policy: policy)
        try CableArithmetic.check(policy)
        return .accepted(state: current,evidence: CableEvolutionEvidence(duration: duration,acceptedSubsteps: accepted,
            attempts: attempts,initialMechanicalEnergy: initialEnergy,finalMechanicalEnergy: currentEnergy,
            externalWork: externalWork,dampingWorkLoss: dampingLoss,originalEnergyResidual: residual,
            maximumSubstepEnergyResidual: maximumEnergyResidual,
            maximumMomentumResidual: max(maximumMomentumResidual,globalMomentumResidual),
            maximumAngularMomentumResidual: max(maximumAngularResidual,globalAngularResidual),
            accumulatedSupportImpulse: supports,numericalWork: work))
    }

    private func advance(_ cable: DiscreteCable, state: NodalState, assembly: CableAssembly, loads: CableLoads,
                         h: Double, oldEnergy: Double, policy: CablePolicy,
                         work: inout NumericalWork) throws(CableError) -> CableTrial {
        let n = cable.nodes.count
        var positions = state.positions, velocities = state.velocities
        var supports = [Vector3](repeating: .zero,count: n)
        var externalWork = 0.0, dragWork = 0.0
        var applied = Vector3.zero, angularApplied = Vector3.zero
        for i in 0..<n {
            try CableArithmetic.check(policy); try CableArithmetic.charge(200,&work)
            let mass = assembly.lumpedNodeMass[i]
            let external = try CableArithmetic.add(loads.heldNodalForces[i],CableArithmetic.scale(loads.heldGravity,mass))
            let environmental = try CableArithmetic.add(external,assembly.physicalDampingForce[i])
            let net = try CableArithmetic.add(environmental,assembly.physicalInternalForce[i])
            if loads.fixedNodes[i] {
                supports[i] = try CableArithmetic.scale(net,-h)
            } else {
                velocities[i] = try CableArithmetic.add(state.velocities[i],CableArithmetic.scale(net,h/mass))
                positions[i] = try CableArithmetic.add(state.positions[i],CableArithmetic.scale(velocities[i],h))
            }
            let dx = try CableArithmetic.subtract(positions[i],state.positions[i])
            externalWork = try CableArithmetic.finite(externalWork+CableArithmetic.dot(external,dx))
            dragWork = try CableArithmetic.finite(dragWork+CableArithmetic.dot(assembly.physicalDampingForce[i],dx))
            let impulse = try CableArithmetic.add(CableArithmetic.scale(environmental,h),supports[i])
            applied = try CableArithmetic.add(applied,impulse)
            angularApplied = try CableArithmetic.add(angularApplied,CableArithmetic.cross(state.positions[i],impulse))
        }
        // Explicit drag must dissipate work over this actual displacement, not just old-time power.
        guard dragWork <= 0 else { throw .acceptanceFailed }
        let candidate = NodalState(frame: state.frame,meshRevision: state.meshRevision,nodeIdentifiers: state.nodeIdentifiers,
                                   positions: positions,velocities: velocities)
        let service: any CableAssembling = ObjectiveCableAssembler()
        let newAssembly = try service.assemble(cable,state: candidate,derivativeOrder: .forceOnly,policy: policy,work: &work)
        let energy = try mechanicalEnergy(candidate,assembly: newAssembly,policy: policy,work: &work)
        let residual = try CableArithmetic.finite(energy-oldEnergy-externalWork-dragWork)
        guard try within(abs(residual),absolute: policy.absoluteEnergyTolerance,
                         scale: max(abs(energy),max(abs(oldEnergy),abs(externalWork)+abs(dragWork))),policy: policy) else { throw .acceptanceFailed }
        let p0 = try momentum(state,mass: assembly.lumpedNodeMass,angular: false,policy: policy,work: &work)
        let p1 = try momentum(candidate,mass: assembly.lumpedNodeMass,angular: false,policy: policy,work: &work)
        let l0 = try momentum(state,mass: assembly.lumpedNodeMass,angular: true,policy: policy,work: &work)
        let l1 = try momentum(candidate,mass: assembly.lumpedNodeMass,angular: true,policy: policy,work: &work)
        let momentumResidual = try balance(p0,p1,impulse: applied,absolute: policy.absoluteMomentumTolerance,policy: policy)
        let angularResidual = try balance(l0,l1,impulse: angularApplied,absolute: policy.absoluteAngularMomentumTolerance,policy: policy)
        try CableArithmetic.check(policy)
        return CableTrial(state: candidate,mechanicalEnergy: energy,externalWork: externalWork,dampingWorkLoss: -dragWork,
                          energyResidual: residual,momentumResidual: momentumResidual,angularMomentumResidual: angularResidual,
                          appliedImpulse: applied,appliedAngularImpulse: angularApplied,supportImpulse: supports)
    }
    private func mechanicalEnergy(_ state: NodalState, assembly: CableAssembly, policy: CablePolicy,
                                  work: inout NumericalWork) throws(CableError) -> Double {
        var energy = assembly.storedEnergy
        for i in state.velocities.indices {
            try CableArithmetic.check(policy); try CableArithmetic.charge(12,&work)
            energy = try CableArithmetic.finite(energy + 0.5*assembly.lumpedNodeMass[i]*CableArithmetic.dot(state.velocities[i],state.velocities[i]))
        }
        return energy
    }
    private func momentum(_ state: NodalState, mass: [Double], angular: Bool, policy: CablePolicy,
                          work: inout NumericalWork) throws(CableError) -> Vector3 {
        var result = Vector3.zero
        for i in mass.indices {
            try CableArithmetic.check(policy); try CableArithmetic.charge(25,&work)
            let p = try CableArithmetic.scale(state.velocities[i],mass[i])
            result = try CableArithmetic.add(result,angular ? CableArithmetic.cross(state.positions[i],p) : p)
        }
        return result
    }
    private func balance(_ before: Vector3, _ after: Vector3, impulse: Vector3, absolute: Double,
                         policy: CablePolicy) throws(CableError) -> Double {
        let residual = try CableArithmetic.norm(CableArithmetic.subtract(CableArithmetic.subtract(after,before),impulse))
        let scale = try max(CableArithmetic.norm(before),max(CableArithmetic.norm(after),CableArithmetic.norm(impulse)))
        guard try within(residual,absolute: absolute,scale: scale,policy: policy) else { throw .acceptanceFailed }
        return residual
    }
    private func within(_ residual: Double, absolute: Double, scale: Double,
                        policy: CablePolicy) throws(CableError) -> Bool {
        let limit = try CableArithmetic.finite(absolute+policy.relativeTolerance*scale)
        return residual <= limit
    }
}
