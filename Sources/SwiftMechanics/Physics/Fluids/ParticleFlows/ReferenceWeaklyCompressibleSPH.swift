public struct ReferenceWeaklyCompressibleSPH: ParticleFlowOperating, Sendable {
    private let kernel = WendlandC2Kernel()
    public init() {}

    public func prepare(model: ParticleFlowModel, particles: [FlowParticle], time: Double,
                        policy: ParticleFlowPolicy, work: inout NumericalWork) throws(ParticleFlowError) -> ParticleFlowState {
        try admission(model, particles, time, policy, &work)
        return try original(model, particles, time, 0, nil, policy, &work).state
    }

    public func evaluate(_ state: ParticleFlowState, expected: ParticleFlowIdentity, timeStep: Double?,
                         policy: ParticleFlowPolicy, work: inout NumericalWork) throws(ParticleFlowError) -> ParticleFlowDiagnostics {
        guard state.model.identity == expected else { throw .identityMismatch }
        try admission(state.model, state.particles, state.time, policy, &work)
        let result = try original(state.model, state.particles, state.time, state.revision, timeStep, policy, &work)
        try ParticleFlowMath.charge(state.particles.count * 12, &work)
        guard result.state == state else { throw .identityMismatch }
        return result.diagnostics
    }

    public func trial(_ state: ParticleFlowState, expected: ParticleFlowIdentity, timeStep dt: Double,
                      policy: ParticleFlowPolicy, work: inout NumericalWork) throws(ParticleFlowError) -> ParticleFlowTrial {
        guard state.model.identity == expected else { throw .identityMismatch }
        guard dt.isFinite, dt > 0, state.revision < UInt64.max else { throw .invalidInput }
        let midpointTime = try ParticleFlowMath.finite(state.time + dt / 2)
        let endTime = try ParticleFlowMath.finite(state.time + dt)
        guard midpointTime > state.time, endTime > midpointTime else { throw .invalidInput }
        try admission(state.model, state.particles, state.time, policy, &work)
        let start = try original(state.model, state.particles, state.time, state.revision, dt, policy, &work)
        try ParticleFlowMath.charge(state.particles.count * 12, &work)
        guard start.state == state else { throw .identityMismatch }
        let midpointParticles = try updated(state.particles, using: start, positionVelocities: state.particles,
                                            dt: dt / 2, work: &work)
        let middle = try original(state.model, midpointParticles, midpointTime, state.revision, dt, policy, &work)
        let endpointParticles = try updated(state.particles, using: middle, positionVelocities: midpointParticles,
                                            dt: dt, work: &work)
        let end = try original(state.model, endpointParticles, endTime, state.revision + 1, dt, policy, &work)
        try ParticleFlowMath.charge(96 + state.model.ghosts.count * 12, &work)
        var reaction = Vector3.zero, mechanical = 0.0, reservoir = 0.0
        for value in middle.diagnostics.boundaryReactions {
            reaction = try ParticleFlowMath.add(reaction, value.force)
            mechanical = try ParticleFlowMath.finite(mechanical + value.prescribedMechanicalPower)
            reservoir = try ParticleFlowMath.finite(reservoir + value.pressureReservoirPower)
        }
        let gravityForce = try ParticleFlowMath.scale(state.model.gravity, middle.diagnostics.totalFiniteMass)
        let impulse = try ParticleFlowMath.scale(reaction, dt)
        let expectedChange = try ParticleFlowMath.scale(ParticleFlowMath.sub(gravityForce, reaction), dt)
        let actualChange = try ParticleFlowMath.sub(end.diagnostics.momentum, start.diagnostics.momentum)
        let momentumResidual = try ParticleFlowMath.norm(ParticleFlowMath.sub(actualChange, expectedChange))
        let mechanicalWork = try ParticleFlowMath.finite(dt * mechanical)
        let reservoirWork = try ParticleFlowMath.finite(dt * reservoir)
        let energyResidual = try ParticleFlowMath.finite(end.diagnostics.totalEnergy - start.diagnostics.totalEnergy
                                                         - mechanicalWork - reservoirWork)
        try ParticleFlowMath.gate(momentumResidual, "midpoint momentum", policy.momentum)
        try ParticleFlowMath.gate(energyResidual, "midpoint total energy", policy.energy)
        try ParticleFlowMath.charge(1, &work)
        return ParticleFlowTrial(originalRevision: state.revision, candidate: end.state,
            initialDiagnostics: start.diagnostics,
            midpointDiagnostics: middle.diagnostics, endpointDiagnostics: end.diagnostics,
            momentumResidual: momentumResidual, energyResidual: energyResidual,
            prescribedMechanicalWork: mechanicalWork, pressureReservoirWork: reservoirWork,
            boundaryImpulse: impulse, work: work)
    }

    private func admission(_ model: ParticleFlowModel, _ particles: [FlowParticle], _ time: Double,
                           _ policy: ParticleFlowPolicy, _ work: inout NumericalWork) throws(ParticleFlowError) {
        guard time.isFinite, !particles.isEmpty, work.budget == policy.budget,
              policy.minimumSeparation < 2 * model.material.smoothingLength else { throw .invalidInput }
        switch model.capability {
        case .compressiveBulkWithPrescribedGhosts: break
        // FIXME(INCOMPLETE_IMPLEMENTATION): Free-surface/tensile stabilization is absent.
        // prepare/evaluate/trial reach this branch; no success is permitted before a qualified tensile law and surface treatment exist.
        case .freeSurfaceWithTensileControl: throw .unsupportedFreeSurface
        // FIXME(INCOMPLETE_IMPLEMENTATION): Dynamic rigid-fluid feedback is absent.
        // prepare/evaluate/trial reach this branch; no success is permitted before paired rigid dynamics and publication are qualified.
        case .dynamicRigidFluidFeedback: throw .unsupportedDynamicBoundary
        }
        var metadata = 0
        for text in [model.identity.key, model.identity.source.source, model.identity.frame.key] {
            for _ in text.utf8 {
                try ParticleFlowMath.charge(1, &work)
                guard metadata < policy.maximumMetadataBytes else { throw .invalidInput }
                metadata += 1
            }
        }
        do throws(NumericalError) {
            let count = try NumericalWork.sum(particles.count, model.ghosts.count)
            // Conservative peak slots include retained inputs, three evaluations, two stage arrays,
            // ghost snapshots/reactions and verification temporaries. No pair-sized buffer exists.
            try work.requireStorage(try NumericalWork.sum(128, NumericalWork.sum(metadata, NumericalWork.sum(
                NumericalWork.product(particles.count, 240), NumericalWork.product(model.ghosts.count, 96)))))
            _ = try NumericalWork.product(count, count)
        } catch { throw .numerical(error) }
        for i in particles.indices {
            try ParticleFlowMath.row(&work)
            for j in particles.indices where j < i {
                try ParticleFlowMath.charge(2, &work)
                guard particles[i].id != particles[j].id else { throw .duplicateIdentity(particles[i].id) }
            }
            for ghost in model.ghosts {
                try ParticleFlowMath.charge(2, &work)
                guard particles[i].id != ghost.id else { throw .duplicateIdentity(ghost.id) }
            }
        }
        for i in model.ghosts.indices {
            try ParticleFlowMath.row(&work)
            for j in model.ghosts.indices where j < i {
                try ParticleFlowMath.charge(2, &work)
                guard model.ghosts[i].id != model.ghosts[j].id else { throw .duplicateIdentity(model.ghosts[i].id) }
            }
        }
    }

    private func updated(_ original: [FlowParticle], using evaluation: ParticleFlowEvaluation,
                         positionVelocities: [FlowParticle], dt: Double,
                         work: inout NumericalWork) throws(ParticleFlowError) -> [FlowParticle] {
        var result: [FlowParticle] = []; result.reserveCapacity(original.count)
        for i in original.indices {
            try ParticleFlowMath.charge(40, &work)
            let value = original[i]
            let position = try ParticleFlowMath.add(value.position, ParticleFlowMath.scale(positionVelocities[i].velocity, dt))
            let velocity = try ParticleFlowMath.add(value.velocity, ParticleFlowMath.scale(evaluation.force[i], dt / value.mass))
            let heat = try ParticleFlowMath.finite(value.viscousHeat + dt * evaluation.heatRate[i])
            result.append(try FlowParticle(id: value.id, mass: value.mass, position: position, velocity: velocity, viscousHeat: heat))
        }
        return result
    }

    private func eos(_ density: Double, _ id: UInt64, _ material: ParticleFlowMaterial,
                     _ policy: ParticleFlowPolicy, _ work: inout NumericalWork) throws(ParticleFlowError)
        -> (pressure: Double, energy: Double, sound: Double) {
        try ParticleFlowMath.charge(32, &work)
        guard density.isFinite, density > 0 else { throw .nonFiniteArithmetic }
        guard density >= material.referenceDensity else { throw .tensileDomain(particle: id, density: density) }
        let ratio = try ParticleFlowMath.finite(density / material.referenceDensity)
        let squareDensity = try ParticleFlowMath.finite(density * density)
        guard squareDensity > 0 else { throw .nonFiniteArithmetic }
        let deviation = ratio - 1
        guard deviation <= policy.maximumRelativeDensityDeviation else { throw .densityDomain(particle: id, relativeDeviation: deviation) }
        let power = try ParticleFlowMath.power(ratio, material.taitExponent - 1, &work)
        let remainder = try ParticleFlowMath.taitRemainder(deviation, material.taitExponent, &work)
        let bulk = try ParticleFlowMath.finite(material.referenceDensity * material.referenceSoundSpeed
                                               * material.referenceSoundSpeed / Double(material.taitExponent))
        guard bulk > 0 else { throw .nonFiniteArithmetic }
        let pressure = try ParticleFlowMath.finite(bulk * remainder.offset)
        let energy = try ParticleFlowMath.finite(bulk / material.referenceDensity
            * remainder.remainder / (Double(material.taitExponent - 1) * ratio))
        let sound = try ParticleFlowMath.finite(material.referenceSoundSpeed * power.squareRoot())
        guard pressure >= 0, energy >= 0, sound > 0 else { throw .nonFiniteArithmetic }
        return (pressure, energy, sound)
    }

    private func original(_ model: ParticleFlowModel, _ particles: [FlowParticle], _ time: Double,
                          _ revision: UInt64, _ dt: Double?, _ policy: ParticleFlowPolicy,
                          _ work: inout NumericalWork) throws(ParticleFlowError) -> ParticleFlowEvaluation {
        let n = particles.count, ghosts = model.ghosts, g = ghosts.count, material = model.material, h = material.smoothingLength
        if let dt { guard dt.isFinite, dt > 0 else { throw .invalidInput } }
        try ParticleFlowMath.row(&work)
        // Charge the bounded array initialization and fixed scalar/vector bookkeeping before allocation.
        try ParticleFlowMath.charge(n * 180 + g * 60 + 128, &work)
        var positions: [Vector3] = [], weights: [Double] = [], ghostPressure: [Double] = [], ghostSound: [Double] = []
        positions.reserveCapacity(g); weights.reserveCapacity(g); ghostPressure.reserveCapacity(g); ghostSound.reserveCapacity(g)
        for ghost in ghosts {
            try ParticleFlowMath.charge(32, &work)
            positions.append(try ParticleFlowMath.add(ghost.referencePosition, ParticleFlowMath.scale(ghost.velocity, time - ghost.referenceTime)))
            let weight = try ParticleFlowMath.finite(ghost.volume * ghost.density)
            guard weight > 0 else { throw .nonFiniteArithmetic }
            weights.append(weight)
            let law = try eos(ghost.density, ghost.id, material, policy, &work)
            ghostPressure.append(law.pressure); ghostSound.append(law.sound)
        }
        var densities = [Double](repeating: 0, count: n)
        let selfKernel = try kernel.value(displacement: .zero, smoothingLength: h)
        try ParticleFlowMath.charge(64, &work)
        for i in particles.indices {
            try ParticleFlowMath.row(&work)
            densities[i] = try ParticleFlowMath.finite(particles[i].mass * selfKernel)
            for j in particles.indices where j != i {
                try ParticleFlowMath.charge(96, &work)
                let delta = try ParticleFlowMath.sub(particles[i].position, particles[j].position)
                try separation(delta, particles[i].id, particles[j].id, policy)
                densities[i] = try ParticleFlowMath.finite(densities[i] + particles[j].mass
                    * kernel.value(displacement: delta, smoothingLength: h))
            }
            for j in ghosts.indices {
                try ParticleFlowMath.charge(96, &work)
                let delta = try ParticleFlowMath.sub(particles[i].position, positions[j])
                try separation(delta, particles[i].id, ghosts[j].id, policy)
                densities[i] = try ParticleFlowMath.finite(densities[i] + weights[j]
                    * kernel.value(displacement: delta, smoothingLength: h))
            }
        }
        var pressures: [Double] = [], energies: [Double] = [], sound: [Double] = []
        pressures.reserveCapacity(n); energies.reserveCapacity(n); sound.reserveCapacity(n)
        for i in particles.indices {
            let law = try eos(densities[i], particles[i].id, material, policy, &work)
            pressures.append(law.pressure); energies.append(law.energy); sound.append(law.sound)
        }
        var forces = [Vector3](repeating: .zero, count: n), densityRate = [Double](repeating: 0, count: n)
        var heatRate = [Double](repeating: 0, count: n), damping = [Double](repeating: 0, count: n)
        var reactions = [Vector3](repeating: .zero, count: g), mechanical = [Double](repeating: 0, count: g)
        var reservoir = [Double](repeating: 0, count: g)
        var loss = 0.0, candidates = 0, active = 0
        for i in particles.indices {
            try ParticleFlowMath.row(&work)
            forces[i] = try ParticleFlowMath.scale(model.gravity, particles[i].mass)
        }
        for i in particles.indices {
            try ParticleFlowMath.row(&work)
            for j in particles.indices where j > i {
                try ParticleFlowMath.charge(200, &work)
                candidates += 1
                let delta = try ParticleFlowMath.sub(particles[i].position, particles[j].position)
                let velocity = try ParticleFlowMath.sub(particles[i].velocity, particles[j].velocity)
                let gradient = try kernel.gradient(displacement: delta, smoothingLength: h)
                if gradient != .zero { active += 1 }
                let coefficient = try viscosity(delta, gradient, particles[i].mass, particles[j].mass,
                                                densities[i], densities[j], material)
                let pressureFactor = try ParticleFlowMath.finite(-particles[i].mass * particles[j].mass
                    * (pressures[i] / (densities[i] * densities[i]) + pressures[j] / (densities[j] * densities[j])))
                let force = try ParticleFlowMath.sub(ParticleFlowMath.scale(gradient, pressureFactor),
                                                    ParticleFlowMath.scale(velocity, coefficient))
                forces[i] = try ParticleFlowMath.add(forces[i], force)
                forces[j] = try ParticleFlowMath.sub(forces[j], force)
                let compression = try ParticleFlowMath.dot(velocity, gradient)
                densityRate[i] = try ParticleFlowMath.finite(densityRate[i] + particles[j].mass * compression)
                densityRate[j] = try ParticleFlowMath.finite(densityRate[j] + particles[i].mass * compression)
                let dissipated = try ParticleFlowMath.finite(coefficient * ParticleFlowMath.dot(velocity, velocity))
                guard dissipated >= 0 else { throw .nonFiniteArithmetic }
                loss = try ParticleFlowMath.finite(loss + dissipated)
                heatRate[i] = try ParticleFlowMath.finite(heatRate[i] + dissipated / (2 * particles[i].mass))
                heatRate[j] = try ParticleFlowMath.finite(heatRate[j] + dissipated / (2 * particles[j].mass))
                damping[i] = try ParticleFlowMath.finite(damping[i] + coefficient / particles[i].mass)
                damping[j] = try ParticleFlowMath.finite(damping[j] + coefficient / particles[j].mass)
            }
            for j in ghosts.indices {
                try ParticleFlowMath.charge(220, &work)
                candidates += 1
                let delta = try ParticleFlowMath.sub(particles[i].position, positions[j])
                let velocity = try ParticleFlowMath.sub(particles[i].velocity, ghosts[j].velocity)
                let gradient = try kernel.gradient(displacement: delta, smoothingLength: h)
                if gradient != .zero { active += 1 }
                let coefficient = try viscosity(delta, gradient, particles[i].mass, weights[j],
                                                densities[i], ghosts[j].density, material)
                let pressureFactor = try ParticleFlowMath.finite(-particles[i].mass * weights[j]
                    * (pressures[i] / (densities[i] * densities[i]) + ghostPressure[j] / (ghosts[j].density * ghosts[j].density)))
                let force = try ParticleFlowMath.sub(ParticleFlowMath.scale(gradient, pressureFactor),
                                                    ParticleFlowMath.scale(velocity, coefficient))
                forces[i] = try ParticleFlowMath.add(forces[i], force)
                reactions[j] = try ParticleFlowMath.sub(reactions[j], force)
                let compression = try ParticleFlowMath.dot(velocity, gradient)
                densityRate[i] = try ParticleFlowMath.finite(densityRate[i] + weights[j] * compression)
                let dissipated = try ParticleFlowMath.finite(coefficient * ParticleFlowMath.dot(velocity, velocity))
                guard dissipated >= 0 else { throw .nonFiniteArithmetic }
                loss = try ParticleFlowMath.finite(loss + dissipated)
                heatRate[i] = try ParticleFlowMath.finite(heatRate[i] + dissipated / particles[i].mass)
                damping[i] = try ParticleFlowMath.finite(damping[i] + coefficient / particles[i].mass)
                mechanical[j] = try ParticleFlowMath.finite(mechanical[j] + ParticleFlowMath.dot(force, ghosts[j].velocity))
                reservoir[j] = try ParticleFlowMath.finite(reservoir[j] - particles[i].mass * weights[j]
                    * ghostPressure[j] / (ghosts[j].density * ghosts[j].density) * compression)
            }
        }
        let equationResidual = try reevaluate(particles, positions, weights, ghostPressure, model, densities, pressures,
                                             forces, densityRate, heatRate, policy, &work)
        var mass = 0.0, momentum = Vector3.zero, totalEnergy = 0.0, sumForce = Vector3.zero
        var internalPower = 0.0, heatPower = 0.0, energyRate = 0.0, reactionSum = Vector3.zero
        var boundaryPower = 0.0, outputReactions: [ParticleFlowBoundaryReaction] = []
        outputReactions.reserveCapacity(g)
        for i in particles.indices {
            try ParticleFlowMath.charge(120, &work)
            let particle = particles[i], kinetic = try ParticleFlowMath.dot(particle.velocity, particle.velocity) / 2
            let potential = try ParticleFlowMath.dot(model.gravity, particle.position)
            mass = try ParticleFlowMath.finite(mass + particle.mass)
            momentum = try ParticleFlowMath.add(momentum, ParticleFlowMath.scale(particle.velocity, particle.mass))
            totalEnergy = try ParticleFlowMath.finite(totalEnergy + particle.mass * (kinetic + energies[i] + particle.viscousHeat - potential))
            sumForce = try ParticleFlowMath.add(sumForce, forces[i])
            let pressurePower = try ParticleFlowMath.finite(particle.mass * pressures[i]
                / (densities[i] * densities[i]) * densityRate[i])
            let thermalPower = try ParticleFlowMath.finite(particle.mass * heatRate[i])
            internalPower = try ParticleFlowMath.finite(internalPower + pressurePower)
            heatPower = try ParticleFlowMath.finite(heatPower + thermalPower)
            energyRate = try ParticleFlowMath.finite(energyRate + ParticleFlowMath.dot(particle.velocity, forces[i])
                + pressurePower + thermalPower - particle.mass * ParticleFlowMath.dot(model.gravity, particle.velocity))
        }
        for j in ghosts.indices {
            try ParticleFlowMath.charge(20, &work)
            reactionSum = try ParticleFlowMath.add(reactionSum, reactions[j])
            boundaryPower = try ParticleFlowMath.finite(boundaryPower + mechanical[j] + reservoir[j])
            outputReactions.append(ParticleFlowBoundaryReaction(ghostID: ghosts[j].id, force: reactions[j],
                prescribedMechanicalPower: mechanical[j], pressureReservoirPower: reservoir[j]))
        }
        let momentumRateResidual = try ParticleFlowMath.norm(ParticleFlowMath.sub(
            ParticleFlowMath.add(sumForce, reactionSum), ParticleFlowMath.scale(model.gravity, mass)))
        let energyRateResidual = try ParticleFlowMath.finite(energyRate - boundaryPower)
        try ParticleFlowMath.gate(momentumRateResidual, "original momentum rate", policy.force)
        try ParticleFlowMath.gate(energyRateResidual, "original energy rate", policy.power)
        try ParticleFlowMath.gate(heatPower - loss, "original viscous loss", policy.power)
        let stability = try stability(particles, ghosts, densities, sound, ghostSound, forces, densityRate,
                                      damping, time, dt, material, policy, &work)
        let state = ParticleFlowState(model: model, revision: revision, time: time, particles: particles,
                                      densities: densities, pressures: pressures, barotropicEnergies: energies)
        let diagnostics = ParticleFlowDiagnostics(totalFiniteMass: mass, momentum: momentum, totalEnergy: totalEnergy,
            pressureInternalPower: internalPower, viscousLoss: loss, viscousHeatPower: heatPower,
            boundaryReactions: outputReactions, originalMomentumRateResidual: momentumRateResidual,
            originalEnergyRateResidual: energyRateResidual, maximumEquationResidual: equationResidual,
            pairCandidates: candidates, activePairs: active, maximumMach: stability.mach,
            evaluatedTimeStep: dt, maximumTimeStepRatio: stability.ratio)
        return ParticleFlowEvaluation(state: state, diagnostics: diagnostics, force: forces,
                                      densityRate: densityRate, heatRate: heatRate, soundSpeed: sound)
    }

    private func separation(_ delta: Vector3, _ first: UInt64, _ second: UInt64,
                            _ policy: ParticleFlowPolicy) throws(ParticleFlowError) {
        guard try ParticleFlowMath.norm(delta) >= policy.minimumSeparation else {
            throw .insufficientSeparation(first: first, second: second)
        }
    }

    private func viscosity(_ delta: Vector3, _ gradient: Vector3, _ firstWeight: Double, _ secondWeight: Double,
                           _ firstDensity: Double, _ secondDensity: Double,
                           _ material: ParticleFlowMaterial) throws(ParticleFlowError) -> Double {
        let denominator = try ParticleFlowMath.finite(ParticleFlowMath.dot(delta, delta)
            + material.viscosityRegularization * material.smoothingLength * material.smoothingLength)
        guard denominator > 0 else { throw .nonFiniteArithmetic }
        let value = try ParticleFlowMath.finite(-2 * material.dynamicViscosity * firstWeight * secondWeight
            / (firstDensity * secondDensity) * ParticleFlowMath.dot(delta, gradient) / denominator)
        guard value >= 0 else { throw .nonFiniteArithmetic }
        return value
    }

    private func reevaluate(_ particles: [FlowParticle], _ ghostPositions: [Vector3], _ ghostWeights: [Double],
                            _ ghostPressure: [Double], _ model: ParticleFlowModel, _ density: [Double],
                            _ pressure: [Double], _ force: [Vector3], _ rate: [Double], _ heat: [Double],
                            _ policy: ParticleFlowPolicy, _ work: inout NumericalWork) throws(ParticleFlowError) -> Double {
        var maximum = 0.0
        let material = model.material, h = material.smoothingLength
        for i in particles.indices {
            try ParticleFlowMath.row(&work)
            var originalForce = try ParticleFlowMath.scale(model.gravity, particles[i].mass)
            var originalRate = 0.0, originalHeat = 0.0
            for j in particles.indices where j != i {
                try ParticleFlowMath.charge(200, &work)
                let r = try ParticleFlowMath.sub(particles[i].position, particles[j].position)
                let dv = try ParticleFlowMath.sub(particles[i].velocity, particles[j].velocity)
                let grad = try kernel.gradient(displacement: r, smoothingLength: h)
                let densityProduct = try ParticleFlowMath.finite(density[i] * density[j])
                let radial = try ParticleFlowMath.dot(r, grad)
                let denominator = try ParticleFlowMath.finite(ParticleFlowMath.dot(r, r) + material.viscosityRegularization * h * h)
                let damping = try ParticleFlowMath.finite(-2 * material.dynamicViscosity * particles[i].mass
                    * particles[j].mass / densityProduct * radial / denominator)
                guard damping >= 0 else { throw .nonFiniteArithmetic }
                let pressureScale = try ParticleFlowMath.finite(-particles[i].mass * particles[j].mass
                    * (pressure[i] / (density[i] * density[i]) + pressure[j] / (density[j] * density[j])))
                originalForce = try ParticleFlowMath.add(originalForce, ParticleFlowMath.scale(grad, pressureScale))
                originalForce = try ParticleFlowMath.sub(originalForce, ParticleFlowMath.scale(dv, damping))
                originalRate = try ParticleFlowMath.finite(originalRate + particles[j].mass * ParticleFlowMath.dot(dv, grad))
                originalHeat = try ParticleFlowMath.finite(originalHeat + damping * ParticleFlowMath.dot(dv, dv) / (2 * particles[i].mass))
            }
            for j in model.ghosts.indices {
                try ParticleFlowMath.charge(200, &work)
                let ghost = model.ghosts[j]
                let r = try ParticleFlowMath.sub(particles[i].position, ghostPositions[j])
                let dv = try ParticleFlowMath.sub(particles[i].velocity, ghost.velocity)
                let grad = try kernel.gradient(displacement: r, smoothingLength: h)
                let denominator = try ParticleFlowMath.finite(ParticleFlowMath.dot(r, r) + material.viscosityRegularization * h * h)
                let damping = try ParticleFlowMath.finite(-2 * material.dynamicViscosity * particles[i].mass
                    * ghostWeights[j] / (density[i] * ghost.density) * ParticleFlowMath.dot(r, grad) / denominator)
                guard damping >= 0 else { throw .nonFiniteArithmetic }
                let pressureScale = try ParticleFlowMath.finite(-particles[i].mass * ghostWeights[j]
                    * (pressure[i] / (density[i] * density[i]) + ghostPressure[j] / (ghost.density * ghost.density)))
                originalForce = try ParticleFlowMath.add(originalForce, ParticleFlowMath.scale(grad, pressureScale))
                originalForce = try ParticleFlowMath.sub(originalForce, ParticleFlowMath.scale(dv, damping))
                originalRate = try ParticleFlowMath.finite(originalRate + ghostWeights[j] * ParticleFlowMath.dot(dv, grad))
                originalHeat = try ParticleFlowMath.finite(originalHeat + damping * ParticleFlowMath.dot(dv, dv) / particles[i].mass)
            }
            let forceResidual = try ParticleFlowMath.norm(ParticleFlowMath.sub(originalForce, force[i]))
            let rateResidual = try ParticleFlowMath.finite(originalRate - rate[i])
            let heatResidual = try ParticleFlowMath.finite(particles[i].mass * (originalHeat - heat[i]))
            try ParticleFlowMath.gate(forceResidual, "original particle force", policy.force)
            try ParticleFlowMath.gate(rateResidual, "original summation density rate", policy.densityRate)
            try ParticleFlowMath.gate(heatResidual, "original particle heat power", policy.power)
            maximum = max(maximum, max(forceResidual / policy.force.scale,
                max(abs(rateResidual) / policy.densityRate.scale, abs(heatResidual) / policy.power.scale)))
        }
        return try ParticleFlowMath.finite(maximum)
    }

    private func stability(_ particles: [FlowParticle], _ ghosts: [PrescribedFlowGhost], _ densities: [Double],
                           _ sound: [Double], _ ghostSound: [Double], _ force: [Vector3], _ densityRate: [Double],
                           _ damping: [Double], _ time: Double, _ dt: Double?, _ material: ParticleFlowMaterial,
                           _ policy: ParticleFlowPolicy, _ work: inout NumericalWork) throws(ParticleFlowError)
        -> (mach: Double, ratio: Double) {
        var maximumMach = 0.0, maximumRatio = 0.0, maximumSpeed = 0.0, maximumSound = 0.0
        for i in particles.indices {
            try ParticleFlowMath.charge(40, &work)
            let speed = try ParticleFlowMath.norm(particles[i].velocity), mach = try ParticleFlowMath.finite(speed / sound[i])
            guard mach <= policy.maximumMach else { throw .machDomain(particle: particles[i].id, mach: mach) }
            maximumMach = max(maximumMach, mach); maximumSpeed = max(maximumSpeed, speed); maximumSound = max(maximumSound, sound[i])
            if let dt {
                let acceleration = try ParticleFlowMath.finite(ParticleFlowMath.norm(force[i]) / particles[i].mass)
                let viscous = try ParticleFlowMath.finite(dt * material.dynamicViscosity / densities[i]
                    / (policy.viscousFactor * material.smoothingLength * material.smoothingLength))
                let rowDamping = try ParticleFlowMath.finite(dt * damping[i] / policy.viscousFactor)
                let densityChange = try ParticleFlowMath.finite(dt * abs(densityRate[i]) / densities[i] / policy.maximumDensityChangeFraction)
                let accelerationRatio: Double
                if acceleration == 0 { accelerationRatio = 0 }
                else {
                    let lengthOverAcceleration = try ParticleFlowMath.finite(material.smoothingLength / acceleration)
                    guard lengthOverAcceleration > 0 else { throw .nonFiniteArithmetic }
                    accelerationRatio = try ParticleFlowMath.finite(dt
                        / (policy.accelerationFactor * lengthOverAcceleration.squareRoot()))
                }
                maximumRatio = max(maximumRatio, max(viscous, max(rowDamping, max(densityChange, accelerationRatio))))
            }
        }
        for j in ghosts.indices {
            try ParticleFlowMath.charge(24, &work)
            let speed = try ParticleFlowMath.norm(ghosts[j].velocity), mach = try ParticleFlowMath.finite(speed / ghostSound[j])
            guard mach <= policy.maximumMach else { throw .machDomain(particle: ghosts[j].id, mach: mach) }
            maximumMach = max(maximumMach, mach); maximumSpeed = max(maximumSpeed, speed); maximumSound = max(maximumSound, ghostSound[j])
        }
        if let dt {
            let acoustic = try ParticleFlowMath.finite(dt * (maximumSound + 2 * maximumSpeed)
                / (policy.courantFactor * material.smoothingLength))
            maximumRatio = max(maximumRatio, acoustic)
            guard maximumRatio <= 1 else { throw .timeStepDomain(stage: time, ratio: maximumRatio) }
        }
        return (maximumMach, maximumRatio)
    }
}
