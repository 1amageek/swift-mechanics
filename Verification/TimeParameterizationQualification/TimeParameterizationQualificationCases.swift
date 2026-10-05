import SwiftMechanics

public enum TimeParameterizationQualificationCases {
    private typealias F = TimeParameterizationQualificationFixtures
    private typealias Failure = TimeParameterizationQualificationError

    private static func check(_ condition: Bool, _ message: String) throws(Failure) {
        guard condition else { throw .assertion(message) }
    }
    private static func near(_ actual: Double, _ expected: Double, _ message: String) throws(Failure) {
        guard actual.isFinite, expected.isFinite,
              abs(actual-expected) <= 1e-9 + 1e-9*max(abs(actual), abs(expected)) else { throw .assertion(message) }
    }
    private static func vector(_ actual: Vector3, _ x: Double, _ y: Double, _ z: Double, _ message: String) throws(Failure) {
        try near(actual.x, x, message + " x"); try near(actual.y, y, message + " y"); try near(actual.z, z, message + " z")
    }
    private static func expect(_ label: String, _ matches: (RetimingError) -> Bool,
                               _ operation: () throws(RetimingError) -> Void) throws(Failure) {
        do throws(RetimingError) { try operation() }
        catch {
            guard matches(error) else { throw .retiming(error) }
            return
        }
        throw .assertion(label + " did not reject")
    }
    private static func rejection(_ request: RetimingRequest, policy: RetimingPolicy? = nil,
                                  label: String, matches: (RetimingError) -> Bool) throws(Failure) {
        let admitted: RetimingPolicy
        if let policy { admitted = policy } else { admitted = try F.policy() }
        var work = try F.numerical(), load = try F.loads()
        let retimer: any PhysicalPathRetiming = PrismaticQuinticRetimer()
        try expect(label, matches) { () throws(RetimingError) in
            _ = try retimer.parameterize(request, policy: admitted, loadWork: &load, work: &work)
        }
    }
    private static func polynomial(_ u: Double) -> (Double, Double, Double) {
        let u2 = u*u, u3 = u2*u, u4 = u3*u, u5 = u4*u
        return (10*u3-15*u4+6*u5, 30*u2-60*u3+30*u4, 60*u-180*u2+120*u3)
    }
    private static func extrema(_ segment: RetimingSegment, displacement: [Double], coefficients: [Double],
                                bias: [Double], limits: [RetimingCoordinateLimits]) throws(Failure) {
        let speedMaximum = 15.0/8, accelerationMaximum = 10.0/3.0.squareRoot()
        for i in displacement.indices {
            let c = segment.coordinates[i], h = segment.duration
            let speed = displacement[i]*speedMaximum/h
            let acceleration = abs(displacement[i])*accelerationMaximum/(h*h)
            let effort = abs(coefficients[i])*accelerationMaximum/(h*h)
            try near(c.displacement, displacement[i], "Original segment displacement")
            try near(c.originalInertiaCoefficient, coefficients[i], "Original coupled inertia action")
            try near(c.staticEffort, bias[i], "Original gravity and held-load bias")
            try check(c.speedRange.contains(0) && c.speedRange.contains(speed), "Analytic signed speed extremum covered")
            try check(c.accelerationRange.contains(-acceleration) && c.accelerationRange.contains(acceleration), "Both acceleration extrema covered")
            try check(c.effortRange.contains(bias[i]-effort) && c.effortRange.contains(bias[i]+effort), "Both shifted physical effort extrema covered")
            try check(limits[i].speed.contains(c.speedRange.lower) && limits[i].speed.contains(c.speedRange.upper), "Full speed certificate accepted")
            try check(limits[i].acceleration.contains(c.accelerationRange.lower) && limits[i].acceleration.contains(c.accelerationRange.upper), "Full acceleration certificate accepted")
            try check(limits[i].effort.contains(c.effortRange.lower) && limits[i].effort.contains(c.effortRange.upper), "Full effort certificate accepted")
        }
    }

    public static func originalCoupledPhysicalTree() throws(TimeParameterizationQualificationError) {
        let source = try F.coupled()
        let limits = try [F.limit(speed: (-1.2, 0.8), acceleration: (-3, 2), effort: (70, 110)),
                          F.limit(speed: (-0.7, 0.6), acceleration: (-2, 1), effort: (25, 70))]
        let points = [[0.2, -0.1], [1.2, 0.4], [0.7, 1.15]]
        let path = try F.parameterize(F.request(source, points: points, limits: limits, origin: 3))
        let mass = [10.0, 4.8, 4.8, 8.0]
        for i in mass.indices { try near(path.referenceMassMatrix[i], mass[i], "Independent translational kinetic-energy mass matrix") }
        try near(path.staticEffort[0], 93, "First gravity and held effort")
        try near(path.staticEffort[1], 50, "Second gravity and held effort")
        try check(path.loadWork.consumed == 4 && path.numericalWork.operations > 0 && path.numericalWork.peakScalarStorage > 0, "Actual supplier work retained")
        let displacements = [[1.0, 0.5], [-0.5, 0.75]], coefficients = [[12.4, 8.8], [-1.4, 3.6]]
        let fractions = [0.0, 0.1, (3-3.0.squareRoot())/6, 0.5, (3+3.0.squareRoot())/6, 0.9, 1.0]
        for index in path.segments.indices {
            let segment = path.segments[index]
            try extrema(segment, displacement: displacements[index], coefficients: coefficients[index], bias: [93, 50], limits: limits)
            for u in fractions {
                let time = u == 1 ? segment.endTime : segment.startTime + u*segment.duration
                let sample = try F.sample(path, time: time)
                let actualU = (time-segment.startTime)/segment.duration
                let p = polynomial(actualU), h = segment.duration
                for i in 0..<2 {
                    try near(sample.state.q[i], points[index][i]+displacements[index][i]*p.0, "Independent quintic position")
                    try near(sample.state.v[i], displacements[index][i]*p.1/h, "Independent physical velocity")
                    try near(sample.state.acceleration[i], displacements[index][i]*p.2/(h*h), "Independent physical acceleration")
                }
                let q1 = sample.state.q[0], q2 = sample.state.q[1], v1 = sample.state.v[0], v2 = sample.state.v[1]
                let a1 = sample.state.acceleration[0], a2 = sample.state.acceleration[1]
                let first = sample.snapshot.bodies[1], second = sample.snapshot.bodies[2], tip = sample.snapshot.bodies[3]
                try vector(first.motion.pose.translation, 1, 1.5+q1, 3, "Original rotated parent anchor and child offset")
                try vector(second.motion.pose.translation, 0.15-0.8*q2, 1.7+q1+0.6*q2, 3, "Original composed second body position")
                try vector(tip.motion.pose.translation, -0.65-0.8*q2, 2.3+q1+0.6*q2, 3, "Original fixed descendant")
                try vector(first.motion.velocity.linear, 0, v1, 0, "First body velocity")
                try vector(second.motion.velocity.linear, -0.8*v2, v1+0.6*v2, 0, "Coupled second body velocity")
                try vector(tip.motion.acceleration.linear, -0.8*a2, a1+0.6*a2, 0, "Fixed descendant acceleration")
                for body in sample.snapshot.bodies {
                    try vector(body.motion.velocity.angular, 0, 0, 0, "Structural zero angular velocity")
                    try vector(body.accelerationBias.linear, 0, 0, 0, "Zero Coriolis and centripetal bias")
                }
                let physical = [10*a1+4.8*a2+93, 4.8*a1+8*a2+50]
                for i in 0..<2 {
                    try near(sample.effort[i], physical[i], "Independent original SI required effort")
                    try near(sample.analyticEffort[i], physical[i], "Analytic effort matches independent original mechanics")
                }
                try F.translated {
                    let state = try KinematicState(revision: F.revision, time: time, q: sample.state.q, v: sample.state.v, acceleration: [0, 0])
                    let snapshot = try TreeKinematicsEvaluator().evaluate(source.tree, state: state, policy: path.policy.jointPolicy)
                    let held = try GeneralizedForceContribution(values: [7, -2], channel: .applied)
                    let input = try RigidDynamicsInput(snapshot: snapshot, velocity: state.v, inertias: source.inertias, gravity: source.gravity, generalizedForces: [held])
                    var work = try F.numerical(), load = try F.loads(), original = [0.0, 0.0]
                    let equations: any RigidEquationComputing = RigidEquationKernel()
                    let system = try equations.assemble(input, admission: path.policy.dynamicsAdmission, loadWork: &load, work: &work)
                    try equations.originalInertialForce(system, acceleration: sample.state.acceleration, includeBias: true, into: &original, work: &work)
                    for i in 0..<2 {
                        let applied = try system.forces.total(at: i)
                        try near(original[i]-applied, physical[i], "Actual qualified original equation replay")
                    }
                }
            }
        }
    }

    public static func originalAnalyticDurationAndSignedExtrema() throws(TimeParameterizationQualificationError) {
        let source = try F.single()
        let speedPositive = try F.limit(speed: (-10, 0.75))
        let speedNegative = try F.limit(speed: (-0.5, 10))
        let acceleration = try F.limit(acceleration: (-0.5, 2))
        let effort = try F.limit(effort: (15, 117))
        let cases: [(Double, RetimingCoordinateLimits, Double)] = [
            (2, speedPositive, 5), (-2, speedNegative, 7.5),
            (2, acceleration, (40.0/3.0.squareRoot()).squareRoot()),
            (2, effort, (20.0/3.0.squareRoot()).squareRoot())]
        for value in cases {
            let path = try F.parameterize(F.request(source, points: [[0], [value.0]], limits: [value.1]))
            let segment = path.segments[0]
            try near(segment.analyticDurationLowerBound, value.2, "Independent active analytic duration")
            try check(segment.duration >= value.2 && segment.duration <= value.2*(1+1e-10), "Duration retains declared floating-point margin")
            try extrema(segment, displacement: [value.0], coefficients: [2*value.0], bias: [17], limits: [value.1])
            for u in [0.0, (3-3.0.squareRoot())/6, 0.5, (3+3.0.squareRoot())/6, 1.0] {
                let sample = try F.sample(path, time: u == 1 ? segment.endTime : u*segment.duration)
                let p = polynomial(sample.fraction)
                try near(sample.effort[0], 2*value.0*p.2/(segment.duration*segment.duration)+17, "Independent single-mass effort extrema and endpoints")
            }
        }
    }

    public static func originalWaypointsClockAndIdentity() throws(TimeParameterizationQualificationError) {
        let source = try F.single(), limit = try F.limit()
        let points = [[0.2], [0.7], [0.7], [-0.1]]
        let path = try F.parameterize(F.request(source, points: points, limits: [limit], origin: 9))
        try check(path.source.sourceID == F.sourceID && path.pathID == F.pathID && path.sourceRevision == F.revision, "Complete original identities")
        try check(path.worldFrame == source.tree.worldFrame && path.coordinateLayout == source.tree.layout, "Original world and complete coordinate layout")
        try check(path.waypoints == points && path.limits == [limit] && path.stopsAtEveryWaypoint, "Original waypoints, signed units and stop policy retained")
        for index in path.segments.indices {
            let segment = path.segments[index]
            try check(segment.index == index && segment.duration > 0 && segment.endTime-segment.startTime == segment.duration, "Representable complete segment clocks")
            let start = try F.sample(path, time: segment.startTime), end = try F.sample(path, time: segment.endTime)
            try check(start.state.q == points[index] && end.state.q == points[index+1], "Exact waypoint positions")
            try check(start.state.v == [0] && start.state.acceleration == [0] && end.state.v == [0] && end.state.acceleration == [0], "C2 rest stops at every waypoint")
            try near(start.effort[0], 17, "Initial static effort"); try near(end.effort[0], 17, "Final static effort")
            if index > 0 { try check(start.segment == index-1, "Shared knot selects preceding closed segment") }
            if index == 1 {
                let middle = try F.sample(path, time: (segment.startTime+segment.endTime)/2)
                try check(middle.state.q == [0.7] && middle.state.v == [0] && middle.state.acceleration == [0], "Repeated waypoint remains constant")
            }
        }
        let last = try F.sample(path, time: path.endTime)
        try check(last.sourceID == F.sourceID && last.pathID == F.pathID && last.sourceRevision == F.revision && last.coordinateLayout == source.tree.layout, "Sample provenance retains caller authority")
        let rounded = try F.parameterize(F.request(source, points: [[0], [0]], limits: [limit], origin: 1e16), policy: F.policy(minimum: 0.1))
        try check(rounded.segments[0].duration == 2 && rounded.endTime > rounded.originTime, "Large finite clock uses representable two-second interval")
        let retimer: any PhysicalPathRetiming = PrismaticQuinticRetimer()
        for query in [RetimingQuery(sourceID: "foreign", pathID: F.pathID, sourceRevision: F.revision, time: 9),
                      RetimingQuery(sourceID: F.sourceID, pathID: "foreign", sourceRevision: F.revision, time: 9),
                      RetimingQuery(sourceID: F.sourceID, pathID: F.pathID, sourceRevision: 40, time: 9)] {
            var work = try F.numerical(), load = try F.loads()
            try expect("Query identity", { if case .identityMismatch = $0 { true } else { false } }) { () throws(RetimingError) in
                _ = try retimer.sample(path, query: query, loadWork: &load, work: &work)
            }
            try check(work.operations == 0 && load.consumed == 0, "Identity refusal publishes no supplier work")
        }
        for time in [path.originTime.nextDown, path.endTime.nextUp, Double.nan, Double.infinity] {
            var work = try F.numerical(), load = try F.loads()
            try expect("Closed clock domain", { if case .outsideClockDomain = $0 { true } else { false } }) { () throws(RetimingError) in
                _ = try retimer.sample(path, query: RetimingQuery(sourceID: F.sourceID, pathID: F.pathID, sourceRevision: F.revision, time: time), loadWork: &load, work: &work)
            }
        }
    }

    public static func originalStaticAndSignedMotionInfeasibility() throws(TimeParameterizationQualificationError) {
        let source = try F.single()
        let staticLimit = try F.limit(effort: (-10, 10))
        try rejection(F.request(source, points: [[0], [0]], limits: [staticLimit]), label: "Static gravity", matches: { if case .infeasibleStaticEffort(coordinate: 0) = $0 { true } else { false } })
        for limit in try [F.limit(speed: (0, 0)), F.limit(acceleration: (0, 1)), F.limit(effort: (17, 100))] {
            try rejection(F.request(source, points: [[0], [1]], limits: [limit]), label: "Zero signed allowance", matches: { if case .infeasibleMotion(segment: 0, coordinate: 0) = $0 { true } else { false } })
        }
        let oneSidedSpeed = try F.limit(speed: (0, 1))
        try rejection(F.request(source, points: [[0], [-1]], limits: [oneSidedSpeed]), label: "Forbidden negative speed", matches: { if case .infeasibleMotion(segment: 0, coordinate: 0) = $0 { true } else { false } })
        let zeroMotion = try F.limit(speed: (0, 0), acceleration: (0, 0), effort: (17, 17))
        let stationary = try F.parameterize(F.request(source, points: [[0.3], [0.3]], limits: [zeroMotion]))
        let sample = try F.sample(stationary, time: stationary.endTime/2)
        try check(sample.state.q == [0.3] && sample.state.v == [0] && sample.state.acceleration == [0], "Zero physical limits admit genuinely stationary waypoint")
        try near(sample.effort[0], 17, "Zero dynamic margin keeps original static effort")
    }

    public static func originalDomainsShapesAndRevisions() throws(TimeParameterizationQualificationError) {
        let limit = try F.limit()
        for source in try [F.single(specification: .revolute(axis: .unitZ)), F.single(placement: .prescribed),
                           F.single(base: .spatialFloating), F.single(specification: .fixed)] {
            let n = source.tree.layout.velocityCount
            let q = [Double](repeating: 0, count: n)
            try rejection(F.request(source, points: [q, q], limits: [RetimingCoordinateLimits](repeating: limit, count: n)), label: "Unsupported chart", matches: { if case .unsupportedDomain = $0 { true } else { false } })
        }
        let original = try F.single()
        let fields = try F.translated { try [AffineGravity(frame: original.tree.worldFrame, accelerationAtOrigin: .zero, gradient: .identity),
                            AffineGravity(frame: original.tree.worldFrame, accelerationAtOrigin: .zero, uniformTimeDerivative: .unitY),
                            AffineGravity(frame: F.id(.frame, "foreign"), accelerationAtOrigin: .zero)] }
        for gravity in fields {
            let source = try F.translated { try RetimingSource(sourceID: F.sourceID, tree: original.tree, inertias: original.inertias, gravity: gravity, heldAppliedForces: [3]) }
            try rejection(F.request(source, points: [[0], [1]], limits: [limit]), label: "Gravity structural admission", matches: {
                if gravity.frame != original.tree.worldFrame { if case .identityMismatch = $0 { return true }; return false }
                if case .unsupportedDomain = $0 { return true }; return false
            })
        }
        try rejection(F.request(original, points: [[0], [1]], limits: [limit], revision: 40), label: "Stale source revision", matches: { if case .identityMismatch = $0 { true } else { false } })
        for points in [[[0.0]], [[0], [Double.nan]], [[0, 1], [1, 2]]] {
            try rejection(F.request(original, points: points, limits: [limit]), label: "Original coordinate shape", matches: { if case .invalidInput = $0 { true } else { false } })
        }
        try rejection(F.request(original, points: [[0], [1]], limits: []), label: "Missing signed limits", matches: { if case .invalidInput = $0 { true } else { false } })
        try rejection(F.request(original, points: [[0], [1]], limits: [limit], identity: ""), label: "Missing path identity", matches: { if case .invalidInput = $0 { true } else { false } })
        for bounds in [(1.0, 0.0), (Double.nan, 1), (0, Double.infinity)] {
            try expect("Physical interval constructor", { if case .invalidInput = $0 { true } else { false } }) { () throws(RetimingError) in
                _ = try RetimingInterval(lower: bounds.0, upper: bounds.1)
            }
        }
        try expect("Source identity constructor", { if case .invalidInput = $0 { true } else { false } }) { () throws(RetimingError) in
            _ = try RetimingSource(sourceID: "", tree: original.tree, inertias: original.inertias, gravity: original.gravity, heldAppliedForces: [3])
        }
        let validPolicy = try F.policy()
        try expect("Policy safety factor constructor", { if case .invalidPolicy = $0 { true } else { false } }) { () throws(RetimingError) in
            _ = try RetimingPolicy(maximumWaypoints: 16, maximumCoordinates: 8, maximumBodies: 8,
                minimumSegmentDuration: 0.01, maximumSegmentDuration: 1000, maximumTotalDuration: 2000, safetyFactor: 1,
                jointPolicy: validPolicy.jointPolicy, dynamicsAdmission: validPolicy.dynamicsAdmission, physicalAgreement: validPolicy.physicalAgreement)
        }
        do throws(TimeParameterizationQualificationError) {
            _ = try F.single(specification: .prismatic(axis: .zero))
            throw Failure.assertion("Zero axis must fail the actual joint constructor")
        } catch {
            guard case .joint(.invalidAxis) = error else { throw error }
        }
    }

    public static func originalWorkCapacityAndCancellation() throws(TimeParameterizationQualificationError) {
        let source = try F.single(), limit = try F.limit(), retimer: any PhysicalPathRetiming = PrismaticQuinticRetimer()
        let request = F.request(source, points: [[0], [1]], limits: [limit]), policy = try F.policy()
        var work = try F.numerical(operations: 1), load = try F.loads()
        try F.translated { try work.chargeOperations(1) }
        try expect("Numerical work", { if case .numerical(.resourceLimit(resource: .arithmeticOperations, limit: 1)) = $0 { true } else { false } }) { () throws(RetimingError) in
            _ = try retimer.parameterize(request, policy: policy, loadWork: &load, work: &work)
        }
        try check(work.operations == 1 && load.consumed == 0, "Previously charged work survives bounded refusal")
        work = try F.numerical(storage: 1); load = try F.loads()
        try expect("Simultaneous storage", { if case .numerical(.resourceLimit(resource: .scalarStorage, limit: 1)) = $0 { true } else { false } }) { () throws(RetimingError) in
            _ = try retimer.parameterize(request, policy: policy, loadWork: &load, work: &work)
        }
        try check(work.operations > 0 && work.peakScalarStorage == 0 && load.consumed == 0, "Storage refusal preserves prior admission work")
        work = try F.numerical(); load = try F.loads(work: 1)
        try F.translated { try load.charge(1) }
        try expect("Original gravity load budget", { if case .dynamics(.loads(.workExhausted)) = $0 { true } else { false } }) { () throws(RetimingError) in
            _ = try retimer.parameterize(request, policy: policy, loadWork: &load, work: &work)
        }
        try check(load.consumed == 1 && work.operations > 0, "Supplier failure preserves consumed physical load and numerical work")
        work = try F.numerical(); load = try F.loads(cancelled: { true })
        try expect("Original load cancellation", { if case .dynamics(.loads(.cancelled)) = $0 { true } else { false } }) { () throws(RetimingError) in
            _ = try retimer.parameterize(request, policy: policy, loadWork: &load, work: &work)
        }
        for cancelledPolicy in try [F.policy(cancelled: { true }), F.policy(dynamicsCancelled: { true })] {
            work = try F.numerical(); load = try F.loads()
            try expect("Declared cancellation", { if case .cancelled = $0 { true } else { false } }) { () throws(RetimingError) in
                _ = try retimer.parameterize(request, policy: cancelledPolicy, loadWork: &load, work: &work)
            }
            try check(work.operations == 0 && load.consumed == 0, "Cancellation precedes publication and work")
        }
        try rejection(request, policy: F.policy(bodies: 1), label: "Body cap", matches: { if case .capacityExceeded = $0 { true } else { false } })
        let coupled = try F.coupled(), wide = try [F.limit(), F.limit()]
        try rejection(F.request(coupled, points: [[0, 0], [1, 1]], limits: wide), policy: F.policy(coordinates: 1), label: "Coordinate cap", matches: { if case .capacityExceeded = $0 { true } else { false } })
        try rejection(F.request(source, points: [[0], [1], [2]], limits: [limit]), policy: F.policy(waypoints: 2), label: "Waypoint cap", matches: { if case .capacityExceeded = $0 { true } else { false } })
        let path = try F.parameterize(request)
        work = try F.numerical(storage: 1); load = try F.loads()
        try expect("Query retained storage", { if case .numerical(.resourceLimit(resource: .scalarStorage, limit: 1)) = $0 { true } else { false } }) { () throws(RetimingError) in
            _ = try retimer.sample(path, query: RetimingQuery(sourceID: F.sourceID, pathID: F.pathID, sourceRevision: F.revision, time: path.originTime), loadWork: &load, work: &work)
        }
        try check(work.operations == 0 && load.consumed == 0, "Replay storage checked before supplier work")
    }

    public static func originalArithmeticAndDurationFailures() throws(TimeParameterizationQualificationError) {
        let source = try F.single(gravity: false), limit = try F.limit()
        let stationary = F.request(source, points: [[0], [0]], limits: [limit])
        let nonfinite: (RetimingError) -> Bool = { if case .nonFiniteArithmetic = $0 { true } else { false } }
        try rejection(F.request(source, points: [[-1e308], [1e308]], limits: [limit]), label: "Finite displacement subtraction overflow", matches: nonfinite)
        try rejection(stationary, policy: F.policy(minimum: Double.leastNormalMagnitude), label: "Duration reciprocal squared overflow", matches: nonfinite)
        try rejection(stationary, policy: F.policy(minimum: 1e200, maximum: 1e201, total: 1e202), label: "Duration reciprocal squared underflow", matches: nonfinite)
        try rejection(F.request(source, points: [[0], [0]], limits: [limit], origin: Double.greatestFiniteMagnitude), label: "Finite clock nextUp overflow", matches: nonfinite)
        try rejection(F.request(source, points: [[0], [0]], limits: [limit], origin: 1e16), policy: F.policy(minimum: 0.1, maximum: 1), label: "Representable clock exceeds segment cap", matches: { if case .durationLimit(segment: 0) = $0 { true } else { false } })
        try rejection(F.request(source, points: [[0], [2]], limits: [F.limit(speed: (-1, 1))]), policy: F.policy(maximum: 1), label: "Original analytic segment duration", matches: { if case .durationLimit(segment: 0) = $0 { true } else { false } })
        try rejection(F.request(source, points: [[0], [0], [0]], limits: [limit]), policy: F.policy(minimum: 1, total: 1.5), label: "Original total duration", matches: { if case .totalDurationLimit = $0 { true } else { false } })
        var work = try F.numerical(operations: Int.max), load = try F.loads()
        try F.translated { try work.chargeOperations(Int.max) }
        let retimer: any PhysicalPathRetiming = PrismaticQuinticRetimer(), policy = try F.policy()
        try expect("Checked cumulative integer work", { if case .numerical(.resourceLimit(resource: .arithmeticOperations, limit: Int.max)) = $0 { true } else { false } }) { () throws(RetimingError) in
            _ = try retimer.parameterize(stationary, policy: policy, loadWork: &load, work: &work)
        }
        try check(work.operations == Int.max && load.consumed == 0, "Integer overflow never wraps or loses consumed work")
    }

    public static func actualNativeCancellation(path: RetimedPath? = nil) throws(TimeParameterizationQualificationError) {
        try check(Task.isCancelled, "Native witness must execute inside actually cancelled Task")
        let source = try F.single(), request = try F.request(source, points: [[0], [1]], limits: [F.limit()])
        var work = try F.numerical(), load = try F.loads()
        let retimer: any PhysicalPathRetiming = PrismaticQuinticRetimer(), policy = try F.policy()
        try expect("Actual Task cancellation", { if case .cancelled = $0 { true } else { false } }) { () throws(RetimingError) in
            _ = try retimer.parameterize(request, policy: policy, loadWork: &load, work: &work)
        }
        try check(work.operations == 0 && load.consumed == 0, "Actual cancellation preserves zero new work")
        if let path {
            try expect("Actual Task query cancellation", { if case .cancelled = $0 { true } else { false } }) { () throws(RetimingError) in
                _ = try retimer.sample(path, query: RetimingQuery(sourceID: F.sourceID, pathID: F.pathID,
                    sourceRevision: F.revision, time: path.originTime), loadWork: &load, work: &work)
            }
            try check(work.operations == 0 && load.consumed == 0, "Actual cancelled query preserves ledgers")
        }

    }
}
