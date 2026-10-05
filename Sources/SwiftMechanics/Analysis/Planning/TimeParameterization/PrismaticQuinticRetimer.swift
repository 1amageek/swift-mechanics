public struct PrismaticQuinticRetimer: PhysicalPathRetiming, Sendable {
    public init() {}

    public func parameterize(_ request: RetimingRequest, policy: RetimingPolicy,
                             loadWork: inout LoadWork, work: inout NumericalWork) throws(RetimingError) -> RetimedPath {
        try RetimingArithmetic.checkpoint(policy)
        let source = request.source, tree = source.tree, n = tree.layout.velocityCount
        guard request.sourceRevision == tree.revision else { throw .identityMismatch }
        guard !request.pathID.isEmpty, request.originTime.isFinite, request.waypoints.count >= 2,
              request.limits.count == n, source.heldAppliedForces.count == n else { throw .invalidInput }
        guard request.waypoints.count <= policy.maximumWaypoints, n <= policy.maximumCoordinates,
              tree.bodies.count <= policy.maximumBodies else { throw .capacityExceeded }
        guard source.inertias.count == tree.bodies.count else { throw .invalidInput }
        try admit(source, policy: policy, work: &work)
        for waypoint in request.waypoints {
            try RetimingArithmetic.checkpoint(policy)
            try RetimingArithmetic.charge(n, &work)
            guard waypoint.count == n, waypoint.allSatisfy({ $0.isFinite }) else { throw .invalidInput }
        }
        let count = request.waypoints.count - 1
        let reserved = try RetimingArithmetic.storage(bodies: tree.bodies.count, joints: tree.joints.count, coordinates: n, segments: count)
        try RetimingArithmetic.reserve(reserved, &work)
        let zero = [Double](repeating: 0, count: n)
        let referenceState = try state(source: source, time: request.originTime, q: request.waypoints[0], v: zero, acceleration: zero)
        let reference = try assemble(source: source, state: referenceState, policy: policy, reserved: reserved, loadWork: &loadWork, work: &work)
        guard reference.inertialBias.allSatisfy({ $0 == 0 }) else { throw .unsupportedDomain }
        var staticEffort = [Double](repeating: 0, count: n)
        for i in 0..<n {
            try RetimingArithmetic.checkpoint(policy)
            try RetimingArithmetic.charge(6, &work)
            let force: Double
            do throws(DynamicsError) { force = try reference.forces.total(at: i) }
            catch { throw .dynamics(error) }
            staticEffort[i] = try RetimingArithmetic.finite(-force)
            guard request.limits[i].effort.contains(staticEffort[i]) else { throw .infeasibleStaticEffort(coordinate: i) }
            guard request.limits[i].speed.contains(0), request.limits[i].acceleration.contains(0) else {
                throw .infeasibleMotion(segment: 0, coordinate: i)
            }
        }
        var segments: [RetimingSegment] = []
        segments.reserveCapacity(count)
        var clock = request.originTime, totalDuration = 0.0
        for segment in 0..<count {
            try RetimingArithmetic.checkpoint(policy)
            var displacement = [Double](repeating: 0, count: n)
            for i in 0..<n {
                try RetimingArithmetic.checkpoint(policy)
                try RetimingArithmetic.charge(1, &work)
                displacement[i] = try RetimingArithmetic.finite(request.waypoints[segment + 1][i] - request.waypoints[segment][i])
            }
            let coefficient = try original(reference, acceleration: displacement, includeBias: false,
                                           policy: policy, reserved: reserved, work: &work)
            var lowerBound = policy.minimumSegmentDuration
            for i in 0..<n {
                try RetimingArithmetic.checkpoint(policy)
                try RetimingArithmetic.charge(24, &work)
                let limits = request.limits[i], d = displacement[i]
                let speedAllowance = d >= 0 ? limits.speed.upper : -limits.speed.lower
                let speedAmplitude = try RetimingArithmetic.finite(abs(d) * RetimingArithmetic.speedMaximum)
                lowerBound = max(lowerBound, try RetimingArithmetic.lowerDuration(amplitude: speedAmplitude, allowance: speedAllowance,
                                                                                  quadratic: false, segment: segment, coordinate: i))
                let accelerationAmplitude = try RetimingArithmetic.finite(abs(d) * RetimingArithmetic.accelerationMaximum)
                lowerBound = max(lowerBound, try RetimingArithmetic.lowerDuration(amplitude: accelerationAmplitude,
                    allowance: min(limits.acceleration.upper, -limits.acceleration.lower), quadratic: true, segment: segment, coordinate: i))
                let effortAmplitude = try RetimingArithmetic.finite(abs(coefficient[i]) * RetimingArithmetic.accelerationMaximum)
                let effortAllowance = try RetimingArithmetic.finite(min(limits.effort.upper - staticEffort[i], staticEffort[i] - limits.effort.lower))
                lowerBound = max(lowerBound, try RetimingArithmetic.lowerDuration(amplitude: effortAmplitude, allowance: effortAllowance,
                                                                                  quadratic: true, segment: segment, coordinate: i))
            }
            let proposedDuration = try RetimingArithmetic.finite((try RetimingArithmetic.finite(lowerBound * policy.safetyFactor * policy.safetyFactor)).nextUp)
            var end = try RetimingArithmetic.finite(clock + proposedDuration)
            if end - clock < proposedDuration { end = try RetimingArithmetic.finite(end.nextUp) }
            // Use the representable clock interval as the interpolation duration; never silently lose elapsed time.
            let duration = try RetimingArithmetic.finite(end - clock)
            guard end > clock, duration >= proposedDuration, duration <= policy.maximumSegmentDuration else { throw .durationLimit(segment: segment) }
            totalDuration = try RetimingArithmetic.finite(totalDuration + duration)
            guard totalDuration <= policy.maximumTotalDuration else { throw .totalDurationLimit }
            let certificates = try certify(displacement: displacement, coefficient: coefficient, staticEffort: staticEffort,
                duration: duration, segment: segment, limits: request.limits, policy: policy, work: &work)
            segments.append(RetimingSegment(index: segment, startTime: clock, endTime: end, duration: duration,
                                           analyticDurationLowerBound: lowerBound, coordinates: certificates))
            clock = end
        }
        try RetimingArithmetic.checkpoint(policy)
        return RetimedPath(request: request, segments: segments, mass: reference.massMatrix, staticEffort: staticEffort,
                           policy: policy, retainedScalars: reserved, numericalWork: work, loadWork: loadWork)
    }

    public func sample(_ path: RetimedPath, query: RetimingQuery,
                       loadWork: inout LoadWork, work: inout NumericalWork) throws(RetimingError) -> RetimingSample {
        let policy = path.policy
        try RetimingArithmetic.checkpoint(policy)
        guard query.sourceID == path.source.sourceID, query.pathID == path.pathID,
              query.sourceRevision == path.sourceRevision else { throw .identityMismatch }
        guard query.time.isFinite, query.time >= path.originTime, query.time <= path.endTime else { throw .outsideClockDomain }
        try RetimingArithmetic.reserve(path.retainedScalars, &work)
        var index = 0
        while query.time > path.segments[index].endTime {
            try RetimingArithmetic.checkpoint(policy); try RetimingArithmetic.charge(1, &work); index += 1
        }
        let segment = path.segments[index], n = path.coordinateLayout.velocityCount
        let fraction: Double
        if query.time == segment.startTime { fraction = 0 }
        else if query.time == segment.endTime { fraction = 1 }
        else { fraction = try RetimingArithmetic.finite((query.time - segment.startTime) / segment.duration) }
        guard fraction >= 0, fraction <= 1 else { throw .nonFiniteArithmetic }
        let inverse = try RetimingArithmetic.finite(1 / segment.duration)
        let u = fraction, complement = 1 - u
        let positionFactor = u <= 0.5 ? u*u*u*(10 + u*(-15 + 6*u)) : 1 - complement*complement*complement*(10 + complement*(-15 + 6*complement))
        let speedFactor = try RetimingArithmetic.finite(30*u*u*complement*complement*inverse)
        let accelerationFactor = try RetimingArithmetic.finite(60*u*complement*(1 - 2*u)*inverse*inverse)
        try RetimingArithmetic.charge(32, &work)
        var q = [Double](repeating: 0, count: n), v = q, acceleration = q, analyticEffort = q
        for i in 0..<n {
            try RetimingArithmetic.checkpoint(policy); try RetimingArithmetic.charge(12, &work)
            let certificate = segment.coordinates[i]
            if u == 0 { q[i] = path.waypoints[index][i] }
            else if u == 1 { q[i] = path.waypoints[index + 1][i] }
            else { q[i] = try RetimingArithmetic.finite(path.waypoints[index][i] + certificate.displacement * positionFactor) }
            v[i] = try RetimingArithmetic.finite(certificate.displacement * speedFactor)
            acceleration[i] = try RetimingArithmetic.finite(certificate.displacement * accelerationFactor)
            analyticEffort[i] = try RetimingArithmetic.finite(certificate.staticEffort + certificate.originalInertiaCoefficient * accelerationFactor)
        }
        let sampledState = try state(source: path.source, time: query.time, q: q, v: v, acceleration: acceleration)
        // Assemble with zero acceleration to avoid roundoff from subtracting J*a from itself in the supplier's bias calculation.
        let equationState = try state(source: path.source, time: query.time, q: q, v: v, acceleration: [Double](repeating: 0, count: n))
        let system = try assemble(source: path.source, state: equationState, policy: policy, reserved: path.retainedScalars,
                                  loadWork: &loadWork, work: &work)
        var effort = try original(system, acceleration: acceleration, includeBias: true, policy: policy,
                                  reserved: path.retainedScalars, work: &work)
        for i in 0..<n {
            try RetimingArithmetic.checkpoint(policy); try RetimingArithmetic.charge(10, &work)
            let force: Double
            do throws(DynamicsError) { force = try system.forces.total(at: i) }
            catch { throw .dynamics(error) }
            effort[i] = try RetimingArithmetic.finite(effort[i] - force)
            let limits = path.limits[i]
            guard limits.speed.contains(v[i]), limits.acceleration.contains(acceleration[i]), limits.effort.contains(effort[i]) else {
                throw .physicalReplayRejected(segment: index, coordinate: i)
            }
            let agrees: Bool
            do throws(CoreError) { agrees = try policy.physicalAgreement.contains(error: effort[i] - analyticEffort[i], scale: max(abs(effort[i]), abs(analyticEffort[i]))) }
            catch { throw .core(error) }
            guard agrees else { throw .physicalReplayRejected(segment: index, coordinate: i) }
        }
        let snapshot = try kinematics(path.source, state: sampledState, policy: policy, work: &work)
        try RetimingArithmetic.checkpoint(policy)
        return RetimingSample(path: path, segment: index, fraction: fraction, state: sampledState, snapshot: snapshot,
                              effort: effort, analyticEffort: analyticEffort, numericalWork: work, loadWork: loadWork)
    }

    // FIXME(INCOMPLETE_IMPLEMENTATION): General rotating/curved/moving-base retiming has no continuous dynamics certificate. The public parameterize path rejects those domains; support requires original inter-knot mechanical bounds before success.
    private func admit(_ source: RetimingSource, policy: RetimingPolicy, work: inout NumericalWork) throws(RetimingError) {
        let tree = source.tree
        try RetimingArithmetic.charge(tree.bodies.count, &work)
        guard tree.rootBase == .fixed, tree.layout.velocityCount > 0,
              tree.layout.positionCount == tree.layout.velocityCount,
              tree.bodies.allSatisfy({ $0.dimension == .spatial }) else { throw .unsupportedDomain }
        guard tree.joints.count == tree.layout.joints.count else { throw .invalidInput }
        for i in tree.joints.indices {
            try RetimingArithmetic.checkpoint(policy); try RetimingArithmetic.charge(16, &work)
            let joint = tree.joints[i], chart = joint.manifold, layout = tree.layout.joints[i]
            guard case .fixed = joint.parentAnchor.placement, case .fixed = joint.childAnchor.placement else { throw .unsupportedDomain }
            guard layout.joint == joint.id, layout.positions.start == layout.velocities.start,
                  layout.positions.count == layout.velocities.count else { throw .unsupportedDomain }
            switch chart.kind {
            case .fixed:
                guard chart.orderedAxes.isEmpty, chart.positionCount == 0, chart.velocityCount == 0,
                      layout.positions.count == 0 else { throw .unsupportedDomain }
            case .prismatic:
                guard chart.orderedAxes.count == 1, chart.orderedAxes[0].kind == .prismatic,
                      chart.positionCount == 1, chart.velocityCount == 1,
                      layout.positions.count == 1 else { throw .unsupportedDomain }
            default: throw .unsupportedDomain
            }
        }
        if let gravity = source.gravity {
            guard gravity.frame == tree.worldFrame else { throw .identityMismatch }
            guard gravity.gradient == .zero, gravity.uniformTimeDerivative == .zero else { throw .unsupportedDomain }
        }
    }

    private func certify(displacement: [Double], coefficient: [Double], staticEffort: [Double], duration: Double,
                         segment: Int, limits: [RetimingCoordinateLimits], policy: RetimingPolicy,
                         work: inout NumericalWork) throws(RetimingError) -> [RetimingCoordinateCertificate] {
        let inverse = try RetimingArithmetic.finite(1 / duration)
        guard inverse > 0, (inverse * inverse).isFinite, inverse * inverse > 0 else { throw .nonFiniteArithmetic }
        var result: [RetimingCoordinateCertificate] = []; result.reserveCapacity(displacement.count)
        for i in displacement.indices {
            try RetimingArithmetic.checkpoint(policy); try RetimingArithmetic.charge(32, &work)
            let d = displacement[i]
            let speed = try RetimingArithmetic.envelope(RetimingArithmetic.scaledAmplitude(d, maximum: RetimingArithmetic.speedMaximum, inverse: inverse, quadratic: false), factor: policy.safetyFactor)
            let acceleration = try RetimingArithmetic.envelope(RetimingArithmetic.scaledAmplitude(d, maximum: RetimingArithmetic.accelerationMaximum, inverse: inverse, quadratic: true), factor: policy.safetyFactor)
            let effort = try RetimingArithmetic.envelope(RetimingArithmetic.scaledAmplitude(coefficient[i], maximum: RetimingArithmetic.accelerationMaximum, inverse: inverse, quadratic: true), factor: policy.safetyFactor)
            let speedRange = RetimingInterval(uncheckedLower: d < 0 ? -speed : 0, upper: d > 0 ? speed : 0)
            let accelerationRange = try RetimingArithmetic.symmetric(radius: acceleration)
            let effortRange = try RetimingArithmetic.symmetric(radius: effort, center: staticEffort[i])
            guard RetimingArithmetic.contains(limits[i].speed, speedRange), RetimingArithmetic.contains(limits[i].acceleration, accelerationRange),
                  RetimingArithmetic.contains(limits[i].effort, effortRange) else { throw .continuousLimitRejected(segment: segment, coordinate: i) }
            result.append(RetimingCoordinateCertificate(speedRange: speedRange, accelerationRange: accelerationRange, effortRange: effortRange,
                displacement: d, originalInertiaCoefficient: coefficient[i], staticEffort: staticEffort[i]))
        }
        return result
    }

    private func state(source: RetimingSource, time: Double, q: [Double], v: [Double], acceleration: [Double]) throws(RetimingError) -> KinematicState {
        do throws(JointError) { return try KinematicState(revision: source.tree.revision, time: time, q: q, v: v, acceleration: acceleration) }
        catch { throw .kinematicSupplierFailure }
    }

    private func kinematics(_ source: RetimingSource, state: KinematicState, policy: RetimingPolicy,
                            work: inout NumericalWork) throws(RetimingError) -> KinematicSnapshot {
        try RetimingArithmetic.checkpoint(policy)
        let cost = try RetimingArithmetic.product(256, RetimingArithmetic.product(source.tree.bodies.count, RetimingArithmetic.sum(source.tree.layout.velocityCount, 1)))
        try RetimingArithmetic.charge(cost, &work)
        let snapshot: KinematicSnapshot
        do { snapshot = try TreeKinematicsEvaluator().evaluate(source.tree, state: state, policy: policy.jointPolicy) }
        catch { throw .kinematicSupplierFailure }
        try RetimingArithmetic.checkpoint(policy); return snapshot
    }

    private func nested(reserved: Int, work: NumericalWork) throws(RetimingError) -> NumericalWork {
        do throws(NumericalError) { return NumericalWork(budget: try work.remainingBudget(reservedStorage: reserved)) }
        catch { throw .numerical(error) }
    }

    private func absorb(_ supplier: NumericalWork, reserved: Int, work: inout NumericalWork) throws(RetimingError) {
        do throws(NumericalError) { try work.absorb(supplier, reservedStorage: reserved) }
        catch { throw .numerical(error) }
    }

    private func assemble(source: RetimingSource, state: KinematicState, policy: RetimingPolicy, reserved: Int,
                          loadWork: inout LoadWork, work: inout NumericalWork) throws(RetimingError) -> RigidDynamicsSystem {
        do throws(LoadError) { try loadWork.charge(0) } catch { throw .dynamics(.loads(error)) }
        let snapshot = try kinematics(source, state: state, policy: policy, work: &work)
        let input: RigidDynamicsInput
        do throws(DynamicsError) {
            let held = try GeneralizedForceContribution(values: source.heldAppliedForces, channel: .applied)
            input = try RigidDynamicsInput(snapshot: snapshot, velocity: state.v, inertias: source.inertias,
                                          gravity: source.gravity, generalizedForces: [held])
        } catch { throw .dynamics(error) }
        var supplier = try nested(reserved: reserved, work: work)
        let system: RigidDynamicsSystem
        do throws(DynamicsError) { system = try RigidEquationKernel().assemble(input, admission: policy.dynamicsAdmission, loadWork: &loadWork, work: &supplier) }
        catch { try absorb(supplier, reserved: reserved, work: &work); throw .dynamics(error) }
        try absorb(supplier, reserved: reserved, work: &work)
        try RetimingArithmetic.checkpoint(policy); return system
    }

    private func original(_ system: RigidDynamicsSystem, acceleration: [Double], includeBias: Bool,
                          policy: RetimingPolicy, reserved: Int, work: inout NumericalWork) throws(RetimingError) -> [Double] {
        try RetimingArithmetic.checkpoint(policy)
        var result = [Double](repeating: 0, count: system.velocityCount), supplier = try nested(reserved: reserved, work: work)
        do throws(DynamicsError) { try RigidEquationKernel().originalInertialForce(system, acceleration: acceleration, includeBias: includeBias, into: &result, work: &supplier) }
        catch { try absorb(supplier, reserved: reserved, work: &work); throw .dynamics(error) }
        try absorb(supplier, reserved: reserved, work: &work)
        try RetimingArithmetic.checkpoint(policy); return result
    }
}
