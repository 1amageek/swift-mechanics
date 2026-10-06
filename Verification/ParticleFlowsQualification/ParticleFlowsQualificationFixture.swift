import SwiftMechanics

struct ParticleFlowsQualificationFixture: Sendable {
    struct Oracle: Sendable {
        let density: [Double]
        let pressure: [Double]
        let energy: [Double]
        let forces: [Vector3]
        let heatRates: [Double]
        let pressurePower: Double
        let loss: Double
        let totalEnergy: Double
        let reaction: Vector3
        let mechanicalPower: Double
        let reservoirPower: Double
    }
    let model: ParticleFlowModel
    let particles: [FlowParticle]
    let time: Double
    static let step = 1e-4

    static func kernel(_ radius: Double, h: Double = 1) -> Double {
        let q = radius / h
        if q >= 2 { return 0 }
        let s = 1 - q / 2
        return 21 / (16 * Double.pi * h * h * h) * s * s * s * s * (1 + 2 * q)
    }
    static func gradient(_ r: Vector3, h: Double = 1) throws -> Vector3 {
        let length = (r.x*r.x+r.y*r.y+r.z*r.z).squareRoot(), q = length / h
        if q >= 2 { return .zero }
        let s = 1 - q / 2
        return try Vector3(r.x, r.y, r.z).scaled(by: -105 / (16 * Double.pi * h*h*h*h*h) * s*s*s)
    }
    /// Independently expanded n=7 polynomial; does not use the production logarithmic composition.
    static func eos(_ density: Double) -> (pressure: Double, energy: Double) {
        let d = density / 1000 - 1
        let coefficients = [7.0,21,35,35,21,7,1]
        var power = d, offset = 0.0, remainder = 0.0
        for i in coefficients.indices {
            let term = coefficients[i] * power
            offset += term
            if i > 0 { remainder += term }
            power *= d
        }
        let bulk = 1000.0 * 100 / 7
        return (bulk * offset, bulk / 1000 * remainder / (6 * (1+d)))
    }
    static func identity(revision: UInt64 = 1) throws -> ParticleFlowIdentity {
        try ParticleFlowIdentity(key: "flow", revision: revision,
            source: SourceProvenance(source: "independent-sph", revision: 3),
            frame: EntityID(kind: .frame, key: "flow-world"), frameRevision: 4)
    }
    static func material(viscosity: Double = 0) throws -> ParticleFlowMaterial {
        try ParticleFlowMaterial(referenceDensity: 1000, referenceSoundSpeed: 10, taitExponent: 7,
            dynamicViscosity: viscosity, smoothingLength: 1, viscosityRegularization: 0.01)
    }
    static func budget(storage: Int = 10000, operations: Int = 1000000,
                       iterations: Int = 1000) throws -> NumericalBudget {
        try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: iterations)
    }
    static func policy(_ budget: NumericalBudget? = nil) throws -> ParticleFlowPolicy {
        let tolerance = try NumericalTolerance(absolute: 1e-9, relative: 1e-11)
        func bound(_ scale: Double) throws -> ParticleFlowResidualScale {
            try ParticleFlowResidualScale(tolerance: tolerance, scale: scale)
        }
        return try ParticleFlowPolicy(budget: budget ?? self.budget(), maximumMetadataBytes: 128,
            minimumSeparation: 0.01, maximumRelativeDensityDeviation: 0.1, maximumMach: 0.3,
            courantFactor: 0.25, viscousFactor: 0.25, accelerationFactor: 0.25,
            maximumDensityChangeFraction: 0.05, densityRate: bound(1000), force: bound(1000),
            power: bound(1000), momentum: bound(1000), energy: ParticleFlowResidualScale(
                tolerance: NumericalTolerance(absolute: 1e-6, relative: 1e-10), scale: 1000))
    }
    static func single(density: Double = 1030, velocity: Vector3 = .zero,
                       gravity: Vector3 = .zero) throws -> Self {
        let m = density / kernel(0)
        return try Self(model: ParticleFlowModel(identity: identity(), material: material(), gravity: gravity,
            ghosts: [], capability: .compressiveBulkWithPrescribedGhosts),
            particles: [FlowParticle(id: 1, mass: m, position: Vector3(0.4,-0.2,0.3), velocity: velocity, viscousHeat: 0)], time: 2)
    }
    static func pair(viscosity: Double = 0, moving: Bool = false) throws -> Self {
        let m = 1030 / (kernel(0) + kernel(1))
        return try Self(model: ParticleFlowModel(identity: identity(), material: material(viscosity: viscosity),
            gravity: .zero, ghosts: [], capability: .compressiveBulkWithPrescribedGhosts), particles: [
            FlowParticle(id: 1, mass: m, position: Vector3(-0.5,0,0), velocity: Vector3(moving ? 0.05 : 0,0.02,0), viscousHeat: 0),
            FlowParticle(id: 2, mass: m, position: Vector3(0.5,0,0), velocity: Vector3(moving ? -0.05 : 0,0.02,0), viscousHeat: 0)], time: 2)
    }
    static func ghost() throws -> Self {
        let mass = 1000 / kernel(0), velocity = try Vector3(0.03,0.01,0)
        let reference = try Vector3(1,0.2,0), position = try reference.adding(velocity)
        let radius = try position.magnitude(), volume = 20 / (1050 * kernel(radius))
        let ghost = try PrescribedFlowGhost(id: 2, volume: volume, density: 1050,
            referencePosition: reference, velocity: velocity, referenceTime: 1)
        return try Self(model: ParticleFlowModel(identity: identity(), material: material(viscosity: 2), gravity: .zero,
            ghosts: [ghost], capability: .compressiveBulkWithPrescribedGhosts), particles: [
                FlowParticle(id: 1, mass: mass, position: .zero, velocity: Vector3(0.1,-0.02,0), viscousHeat: 0)], time: 2)
    }
    func prepare(_ service: any ParticleFlowOperating, policy: ParticleFlowPolicy,
                 work: inout NumericalWork) throws -> ParticleFlowState {
        try service.prepare(model: model, particles: particles, time: time, policy: policy, work: &work)
    }
    func oracle(_ particles: [FlowParticle], time: Double) throws -> Oracle {
        var density: [Double] = [], pressure: [Double] = [], energies: [Double] = []
        for particle in particles {
            var value = 0.0
            for other in particles {
                value += try other.mass * Self.kernel(particle.position.subtracting(other.position).magnitude())
            }
            for ghost in model.ghosts {
                let position = try ghost.referencePosition.adding(ghost.velocity.scaled(by: time-ghost.referenceTime))
                value += try ghost.volume * ghost.density * Self.kernel(particle.position.subtracting(position).magnitude())
            }
            density.append(value)
            let law = Self.eos(value); pressure.append(law.pressure); energies.append(law.energy)
        }
        var force: [Vector3] = [], heat: [Double] = [], loss = 0.0, pressurePower = 0.0
        var reaction = Vector3.zero, mechanical = 0.0, reservoir = 0.0, totalEnergy = 0.0
        for i in particles.indices {
            let a = particles[i]
            var f = try model.gravity.scaled(by: a.mass), rhoRate = 0.0, heatRate = 0.0
            for j in particles.indices where i != j {
                let b = particles[j], r = try a.position.subtracting(b.position), dv = try a.velocity.subtracting(b.velocity)
                let grad = try Self.gradient(r), r2 = try r.dot(r)
                let c = try -2 * model.material.dynamicViscosity * a.mass * b.mass / (density[i]*density[j]) * r.dot(grad) / (r2+0.01)
                f = try f.adding(grad.scaled(by: -a.mass*b.mass*(pressure[i]/(density[i]*density[i])+pressure[j]/(density[j]*density[j])))).subtracting(dv.scaled(by: c))
                rhoRate += try b.mass * dv.dot(grad)
                let dissipated = try c * dv.dot(dv)
                heatRate += dissipated / (2*a.mass); loss += dissipated / 2
            }
            for ghost in model.ghosts {
                let x = try ghost.referencePosition.adding(ghost.velocity.scaled(by: time-ghost.referenceTime))
                let r = try a.position.subtracting(x), dv = try a.velocity.subtracting(ghost.velocity)
                let grad = try Self.gradient(r), weight = ghost.volume*ghost.density, pg = Self.eos(ghost.density).pressure
                let c = try -2*model.material.dynamicViscosity*a.mass*weight/(density[i]*ghost.density)*r.dot(grad)/(r.dot(r)+0.01)
                let pair = try grad.scaled(by: -a.mass*weight*(pressure[i]/(density[i]*density[i])+pg/(ghost.density*ghost.density))).subtracting(dv.scaled(by: c))
                f = try f.adding(pair); reaction = try reaction.subtracting(pair)
                let compression = try dv.dot(grad)
                rhoRate += weight*compression
                let dissipated = try c*dv.dot(dv); heatRate += dissipated/a.mass; loss += dissipated
                mechanical += try pair.dot(ghost.velocity)
                reservoir -= a.mass*weight*pg/(ghost.density*ghost.density)*compression
            }
            force.append(f); heat.append(heatRate)
            pressurePower += a.mass*pressure[i]/(density[i]*density[i])*rhoRate
            totalEnergy += try a.mass*(a.velocity.dot(a.velocity)/2+energies[i]+a.viscousHeat-model.gravity.dot(a.position))
        }
        return Oracle(density: density, pressure: pressure, energy: energies, forces: force, heatRates: heat,
            pressurePower: pressurePower, loss: loss, totalEnergy: totalEnergy, reaction: reaction,
            mechanicalPower: mechanical, reservoirPower: reservoir)
    }
    func midpointEndpoint(dt: Double) throws -> (particles: [FlowParticle], middle: Oracle) {
        let start = try oracle(particles, time: time)
        var midpoint: [FlowParticle] = []
        for i in particles.indices {
            let p = particles[i]
            midpoint.append(try FlowParticle(id: p.id, mass: p.mass,
                position: p.position.adding(p.velocity.scaled(by: dt/2)),
                velocity: p.velocity.adding(start.forces[i].scaled(by: dt/(2*p.mass))),
                viscousHeat: p.viscousHeat+dt*start.heatRates[i]/2))
        }
        let middle = try oracle(midpoint, time: time+dt/2)
        var endpoint: [FlowParticle] = []
        for i in particles.indices {
            let p = particles[i]
            endpoint.append(try FlowParticle(id: p.id, mass: p.mass,
                position: p.position.adding(midpoint[i].velocity.scaled(by: dt)),
                velocity: p.velocity.adding(middle.forces[i].scaled(by: dt/p.mass)),
                viscousHeat: p.viscousHeat+dt*middle.heatRates[i]))
        }
        return (endpoint, middle)
    }
}
