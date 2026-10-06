import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension FoundationVerification {
    @inline(never) static func verifyIslandDynamics() throws {
        let context = try IslandDynamicsProbeContext()
        try verifyIslandMapping(context)
        try verifyIslandOriginalMotion(context)
        try verifyIslandMixedRest(context)
        try verifyIslandAwakeMotion(context.source)
        try verifyIslandBoundedRefusals(context)
    }

    private static func islandNear(_ actual: Double, _ expected: Double) throws {
        try require(actual.isFinite && abs(actual - expected) <= 1e-9 + 1e-10 * abs(expected))
    }

    private static func islandFor(_ context: IslandDynamicsProbeContext, coordinate: Int) throws -> StationaryMechanicalIsland {
        guard let island = context.program.islands.first(where: { $0.sourceCoordinateIndices.contains(coordinate) }) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        return island
    }

    @inline(never) private static func verifyIslandMapping(_ c: IslandDynamicsProbeContext) throws {
        try require(c.program.islands.count == 2 && c.constructionWork.compilationCalls == 2)
        try require(c.program.source.descriptor == c.source.model.descriptor)
        try require(c.program.source.policy == c.source.model.policy)
        try require(c.program.constraints.rows.count == 1 && c.program.constraints.rows[0].id == 7)
        let original = c.program.constraints.rows[0]
        for i in 0..<3 {
            try islandNear(original.linear[i], i == c.source.sliderIndex ? 0 : 1)
        }
        try require(original.constant == 0 && original.timeLinear == 0 && original.timeQuadratic == 0)
        try require(original.hessian.allSatisfy { $0 == 0 } && original.mixedTime.allSatisfy { $0 == 0 })
        let gear = try islandFor(c, coordinate: c.source.firstIndex)
        let free = try islandFor(c, coordinate: c.source.sliderIndex)
        try require(gear.id != free.id && gear.sourceCoordinateIndices.count == 2)
        try require(gear.sourceCoordinateIndices.contains(c.source.secondIndex) && gear.retainedRowIDs == [7])
        try require(free.sourceCoordinateIndices == [c.source.sliderIndex] && free.retainedRowIDs.isEmpty && free.constraints == nil)
        var visited = [Bool](repeating: false, count: 3)
        for island in c.program.islands {
            try require(island.model.policy == c.source.model.policy && island.model.descriptor.root == c.source.model.descriptor.root)
            try require(island.model.tree.bodies.count == island.sourceCoordinateIndices.count + 1)
            for entry in island.model.tree.layout.joints {
                guard let originalEntry = c.source.model.tree.layout.joints.first(where: { $0.joint == entry.joint }) else {
                    throw FoundationVerificationError.analyticCheckFailed
                }
                let local = entry.velocities.start, index = originalEntry.velocities.start
                try require(entry.velocities.count == 1 && entry.positions.count == 1)
                try require(island.sourceCoordinateIndices[local] == index && !visited[index])
                visited[index] = true
                try require(island.coordinateIDs[local] == c.source.constraints.layout.coordinateIDs[index])
                try islandNear(island.drive[local], c.program.drive[index])
            }
            for body in island.model.descriptor.bodies {
                try require(c.source.model.descriptor.bodies.contains(body))
            }
            for joint in island.model.descriptor.joints {
                try require(c.source.model.descriptor.joints.contains(joint))
            }
        }
        try require(visited.allSatisfy { $0 })
        if let rows = gear.constraints {
            try require(rows.rows.count == 1 && rows.rows[0].id == 7 && rows.layout.timeScale == 2)
            for local in gear.sourceCoordinateIndices.indices {
                try islandNear(rows.rows[0].linear[local], original.linear[gear.sourceCoordinateIndices[local]])
                try islandNear(rows.layout.scales[local], 1)
                try require(rows.layout.dimensions[local] == c.source.constraints.layout.dimensions[gear.sourceCoordinateIndices[local]])
            }
        } else { throw FoundationVerificationError.analyticCheckFailed }
        try verifyIslandWork(c.constructionWork)
    }

    /// Original scalar branch inertias give M=diag(2,2,2), zero bias and no external force.
    @inline(never) private static func verifyIslandPhysicalRows(_ c: IslandDynamicsProbeContext,
        motion: StationaryIslandMotion, physical: KinematicState, expectedAcceleration: [Double],
        expectedReaction: [Double], expectedEnergy: Double) throws {
        let island = motion.island, n = island.sourceCoordinateIndices.count
        try require(motion.program === c.program && motion.physical == physical)
        try require(motion.acceleration.count == n && motion.generalizedReaction.count == n)
        try require(motion.system.velocityCount == n && motion.system.massMatrix.count == n*n)
        try require(motion.system.input.snapshot.tree.layout == island.model.tree.layout)
        try require(motion.system.input.inertias.count == motion.system.input.snapshot.bodies.count)
        for i in motion.system.input.inertias.indices {
            let inertia = motion.system.input.inertias[i], body = motion.system.input.snapshot.bodies[i]
            try require(inertia.body == body.body && inertia.frame == body.bodyFrame)
            guard let record = c.source.model.descriptor.bodies.first(where: { $0.id == body.body }),
                  case .spatial(let spatial) = record, let originalInertia = spatial.inertia else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            try require(inertia.properties == originalInertia.properties)
        }
        for i in 0..<n {
            let source = island.sourceCoordinateIndices[i]
            for j in 0..<n { try islandNear(motion.system.massMatrix[i*n+j], i == j ? 2 : 0) }
            try islandNear(motion.system.inertialBias[i], 0)
            try islandNear(motion.system.forces.total(at: i), 0)
            try islandNear(motion.system.input.velocity[i], physical.v[source])
            try islandNear(motion.acceleration[i], expectedAcceleration[source])
            try islandNear(motion.generalizedReaction[i], expectedReaction[source])
            try islandNear(2 * motion.acceleration[i], c.program.drive[source] + motion.generalizedReaction[i])
        }
        try islandNear(motion.kineticEnergy, expectedEnergy)
        if let constrained = motion.constrained {
            try require(constrained.rowIDs == [7] && constrained.temporalMeaning == .accelerationForce)
            try require(constrained.sourceSnapshot.tree.layout == island.model.tree.layout)
            try require(constrained.originalRowResidual <= 1e-9 && constrained.originalPhysicalResidual <= 1e-9)
            var position = 0.0, velocity = 0.0, acceleration = 0.0
            for local in 0..<n {
                let index = island.sourceCoordinateIndices[local]
                let coefficient = index == c.source.sliderIndex ? 0.0 : 1.0
                position += coefficient * physical.q[index]
                velocity += coefficient * physical.v[index]
                acceleration += coefficient * motion.acceleration[local]
            }
            try islandNear(position, 0); try islandNear(velocity, 0); try islandNear(acceleration, 0)
        } else { try require(island.retainedRowIDs.isEmpty && island.constraints == nil) }
    }

    @inline(never) private static func verifyIslandOriginalMotion(_ c: IslandDynamicsProbeContext) throws {
        let physical = try c.source.physical()
        var work = c.makeWork()
        let gear = try c.motion(islandFor(c, coordinate: c.source.firstIndex), physical: physical, work: &work)
        try verifyIslandPhysicalRows(c, motion: gear, physical: physical,
            expectedAcceleration: c.source.drive(first: 0, second: 0, slider: 2),
            expectedReaction: c.source.drive(first: -2, second: -2, slider: 0), expectedEnergy: 0)
        try require(gear.constrained != nil)
        try verifyIslandWork(work)
        try verifyIslandFreeMotion(c, physical: physical)
    }

    @inline(never) private static func verifyIslandFreeMotion(_ c: IslandDynamicsProbeContext, physical: KinematicState) throws {
        var work = c.makeWork()
        let free = try c.motion(islandFor(c, coordinate: c.source.sliderIndex), physical: physical, work: &work)
        try verifyIslandPhysicalRows(c, motion: free, physical: physical,
            expectedAcceleration: c.source.drive(first: 0, second: 0, slider: 2),
            expectedReaction: [0, 0, 0], expectedEnergy: 1)
        try require(free.constrained == nil)
        try verifyIslandWork(work)
    }

    @inline(never) private static func verifyIslandMixedRest(_ c: IslandDynamicsProbeContext) throws {
        let gear = try islandFor(c, coordinate: c.source.firstIndex), physical = try c.source.physical()
        var work = c.makeWork()
        guard let certificate = try c.rest(gear, physical: physical, work: &work) else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        try require(certificate.program === c.program && certificate.islandID == gear.id)
        try islandNear(certificate.kineticEnergy, 0); try islandNear(certificate.normalizedVelocity, 0)
        try require(physical.v[c.source.sliderIndex] != 0)
        let elsewhere = try c.source.physical(sliderPosition: 1.3, sliderVelocity: 2, time: 1)
        try require(try c.associate(certificate, physical: elsewhere, work: &work))
        let displaced = try c.source.physical(firstPosition: 0.2, secondPosition: -0.2)
        try require(!(try c.associate(certificate, physical: displaced, work: &work)))
        let rotating = try c.source.physical(firstVelocity: 0.5, secondVelocity: -0.5)
        try require(!(try c.associate(certificate, physical: rotating, work: &work)))
        let outside = try c.source.physical(time: c.source.constraints.maximumTime + 1)
        try require(!(try c.associate(certificate, physical: outside, work: &work)))
        try verifyIslandNonrest(c, physical: physical)
        try verifyIslandChangedDrive(c, certificate: certificate, physical: physical)
        try verifyIslandChangedInertia(c, certificate: certificate, physical: physical)
        try verifyIslandMalformedState(c, certificate: certificate)
        try verifyIslandWork(work)
    }

    @inline(never) private static func verifyIslandChangedDrive(_ c: IslandDynamicsProbeContext,
        certificate: StationaryIslandRestCertificate, physical: KinematicState) throws {
        let changed = try IslandDynamicsProbeContext(source: c.source, firstDrive: 3, secondDrive: 3)
        try require(changed.program.source.stamp == c.program.source.stamp && changed.program.binding != c.program.binding)
        var work = changed.makeWork()
        try require(!(try changed.associate(certificate, physical: physical, work: &work)))
        try verifyIslandWork(work)
    }

    @inline(never) private static func verifyIslandChangedInertia(_ c: IslandDynamicsProbeContext,
        certificate: StationaryIslandRestCertificate, physical: KinematicState) throws {
        let source = try IslandDynamicsProbeModel(firstRotationalInertia: 4)
        let changed = try IslandDynamicsProbeContext(source: source)
        try require(changed.program.source.stamp == c.program.source.stamp && changed.program.binding != c.program.binding)
        var work = changed.makeWork()
        try require(!(try changed.associate(certificate, physical: physical, work: &work)))
        try verifyIslandWork(work)
    }

    @inline(never) private static func verifyIslandMalformedState(_ c: IslandDynamicsProbeContext,
        certificate: StationaryIslandRestCertificate) throws {
        var work = c.makeWork()
        let stale = try c.source.physical(revision: c.source.model.stamp.revision + 1)
        do {
            _ = try c.associate(certificate, physical: stale, work: &work)
            throw FoundationVerificationError.analyticCheckFailed
        } catch let failure as StationaryIslandFailure {
            guard case .sourceMismatch = failure.reason else { throw FoundationVerificationError.analyticCheckFailed }
            try require(failure.knownWork.numerical == work.numerical)
        }
    }

    @inline(never) private static func verifyIslandNonrest(_ c: IslandDynamicsProbeContext, physical: KinematicState) throws {
        var work = c.makeWork()
        let free = try islandFor(c, coordinate: c.source.sliderIndex)
        try require(try c.rest(free, physical: physical, work: &work) == nil)
        try verifyIslandWork(work)
    }

    @inline(never) private static func verifyIslandAwakeMotion(_ source: IslandDynamicsProbeModel) throws {
        let c = try IslandDynamicsProbeContext(source: source, firstDrive: 2, secondDrive: -2)
        let physical = try source.physical(firstPosition: 0.2, secondPosition: -0.2,
            firstVelocity: 0.5, secondVelocity: -0.5)
        var work = c.makeWork()
        let gear = try c.motion(islandFor(c, coordinate: source.firstIndex), physical: physical, work: &work)
        try verifyIslandPhysicalRows(c, motion: gear, physical: physical,
            expectedAcceleration: source.drive(first: 1, second: -1, slider: 2),
            expectedReaction: [0, 0, 0], expectedEnergy: 0.5)
        try verifyIslandWork(work)
    }

    private static func verifyIslandWork(_ work: StationaryIslandWork) throws {
        try require(work.numerical.operations > 0 && work.numerical.operations <= work.numerical.budget.arithmeticOperations)
        try require(work.numerical.peakScalarStorage <= work.numerical.budget.scalarStorage)
        try require(work.numerical.iterations <= work.numerical.budget.iterations)
        try require(work.loads.consumed <= work.loads.budget.maximumWork && work.loads.peakScalars <= work.loads.budget.maximumScalars)
        try require(!work.failedSupplierWorkUnavailable)
    }

    @inline(never) private static func verifyIslandBoundedRefusals(_ c: IslandDynamicsProbeContext) throws {
        var limited = c.makeWork()
        let policy = try IslandDynamicsProbeContext.makePolicy(maximumIslands: 1)
        do {
            _ = try IslandDynamicsProbeContext.prepare(c.source, drive: c.program.drive, policy: policy, work: &limited)
            throw FoundationVerificationError.analyticCheckFailed
        } catch let failure as StationaryIslandFailure {
            guard case .capacityExceeded = failure.reason else { throw FoundationVerificationError.analyticCheckFailed }
            try require(failure.knownWork.numerical == limited.numerical && failure.knownWork.compilationCalls == 0)
            try require(failure.knownWork.loads.consumed == limited.loads.consumed && !failure.failedSupplierWorkUnavailable)
        }
        try verifyIslandCancelledPreparation(c)
        try verifyIslandExhaustedMotion(c)
    }

    @inline(never) private static func verifyIslandCancelledPreparation(_ c: IslandDynamicsProbeContext) throws {
        var work = c.makeWork()
        let policy = try IslandDynamicsProbeContext.makePolicy(isCancelled: { true })
        do {
            _ = try IslandDynamicsProbeContext.prepare(c.source, drive: c.program.drive, policy: policy, work: &work)
            throw FoundationVerificationError.analyticCheckFailed
        } catch let failure as StationaryIslandFailure {
            guard case .cancelled = failure.reason else { throw FoundationVerificationError.analyticCheckFailed }
            try require(failure.knownWork.numerical == work.numerical && failure.knownWork.compilationCalls == 0)
            try require(failure.knownWork.loads.consumed == work.loads.consumed && !failure.failedSupplierWorkUnavailable)
        }
    }

    @inline(never) private static func verifyIslandExhaustedMotion(_ c: IslandDynamicsProbeContext) throws {
        var work = StationaryIslandWork(numerical: NumericalWork(budget: try NumericalBudget(scalarStorage: 0,
            arithmeticOperations: 1000, iterations: 100)), loads: LoadWork(budget: c.loadBudget))
        do {
            _ = try c.motion(islandFor(c, coordinate: c.source.firstIndex), physical: c.source.physical(), work: &work)
            throw FoundationVerificationError.analyticCheckFailed
        } catch let failure as StationaryIslandFailure {
            guard case .numerical(.resourceLimit(resource: .scalarStorage, limit: 0)) = failure.reason else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            try require(failure.knownWork.numerical == work.numerical)
            try require(failure.knownWork.loads.consumed == work.loads.consumed && !failure.failedSupplierWorkUnavailable)
        }
    }
}
