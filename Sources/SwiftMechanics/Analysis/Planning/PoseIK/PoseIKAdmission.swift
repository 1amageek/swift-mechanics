internal struct PoseIKAdmission: Sendable {
    let problem: PoseIKProblem
    let policy: PoseIKPolicy
    let rows: [UInt64]
    let solverCount: Int
    let retainedStorage: Int
    let callbackStorage: Int
    let evaluationPolicy: ConstraintEvaluationPolicy
    let cosineMargin: Double

    init(_ problem: PoseIKProblem, policy: PoseIKPolicy, work: inout NumericalWork) throws(PoseIKError) {
        try PoseIKArithmetic.check(policy)
        let tree = problem.tree, n = tree.layout.velocityCount
        guard n > 0, n <= policy.maximumCoordinates, tree.bodies.count <= policy.maximumBodies,
              problem.tasks.count <= policy.maximumRows, (problem.loops?.rows.count ?? 0) <= policy.maximumRows else { throw .capacityExceeded }
        guard n <= policy.derivative.maximumVelocities, tree.bodies.count <= policy.derivative.maximumBodies,
              policy.maximumDerivativeCallsPerDirection > tree.bodies.count else { throw .capacityExceeded }
        // FIXME(INCOMPLETE_IMPLEMENTATION): PoseIKSolving.solve admits fixed-root spatial Euclidean charts only; floating/quaternion/planar/prescribed charts fail until retraction, derivatives and original acceptance are implemented and qualified.
        guard tree.rootBase == .fixed, tree.bodies.allSatisfy({ $0.dimension == .spatial }),
              tree.layout.positionCount == n, tree.joints.allSatisfy({ $0.manifold.kind != .spherical && $0.manifold.kind != .sixDOF }) else { throw .unsupportedChart }
        for joint in tree.joints {
            switch (joint.parentAnchor.placement, joint.childAnchor.placement) {
            case (.fixed, .fixed): break
            // FIXME(INCOMPLETE_IMPLEMENTATION): PoseIK initialization does not bind prescribed anchor laws; refuse this callable branch until fixed-time law provenance and exact products are qualified.
            default: throw .unsupportedChart
            }
        }
        guard problem.layout.revision == tree.revision, problem.worldFrame == tree.worldFrame else { throw .staleIdentity }
        let layout = problem.layout
        guard layout.coordinateIDs.count == n, layout.scales.count == n, layout.dimensions.count == n,
              problem.initialPositions.count == n, problem.referencePositions.count == n,
              problem.minimumPositions.count == n, problem.maximumPositions.count == n else { throw .invalidShape }
        guard problem.time.isFinite, layout.timeScale.isFinite, layout.timeScale > 0 else { throw .invalidInput }
        let margin: Double
        switch problem.branch {
        case .suppliedLocal(let value):
            guard value.isFinite, value >= 0, value < 1 else { throw .invalidInput }; margin = value
        // FIXME(INCOMPLETE_IMPLEMENTATION): PoseIKSolving.solve has no branch enumerator; refuse before solving until bounded enumeration and original per-branch acceptance are qualified.
        case .enumerateBranches: throw .unsupportedBranch
        }
        var m = 0
        for task in problem.tasks {
            m = try PoseIKArithmetic.sum(m, task.rowIDs.count)
            guard m <= policy.maximumRows else { throw .capacityExceeded }
        }
        m = try PoseIKArithmetic.sum(m, problem.loops?.rows.count ?? 0)
        guard m > 0, m <= policy.maximumRows else { throw .invalidShape }
        // FIXME(INCOMPLETE_IMPLEMENTATION): The equality KKT solve in PoseIKSolving.solve requires no more rows than coordinates; overdetermined task systems fail until a rank-aware feasibility algorithm preserving every original row is qualified.
        guard m <= n else { throw .unsupportedTaskCount(rows: m, coordinates: n) }
        let d = try PoseIKArithmetic.sum(n, m)
        let square = try PoseIKArithmetic.product(n, n)
        if let loops = problem.loops {
            guard loops.layout.scales.count == n, loops.minimumPosition.count == n, loops.maximumPosition.count == n,
                  loops.rows.allSatisfy({ $0.linear.count == n && $0.mixedTime.count == n && $0.hessian.count == square }) else { throw .invalidShape }
        }
        let retained = try PoseIKArithmetic.sum(policy.maximumIdentityBytes/8+1,
            try PoseIKArithmetic.sum(try PoseIKArithmetic.product(32, d),
                try PoseIKArithmetic.product(problem.loops?.rows.count ?? 0, try PoseIKArithmetic.sum(square, try PoseIKArithmetic.product(3, n)))))
        // Includes live IM04 arrays/factors, primal snapshots, directional workspace/publication and task/loop arrays.
        let callback = try PoseIKArithmetic.sum(retained,
            try PoseIKArithmetic.sum(try PoseIKArithmetic.product(128, try PoseIKArithmetic.product(d, d)),
                try PoseIKArithmetic.product(2048, try PoseIKArithmetic.product(tree.bodies.count, n+1))))
        try PoseIKArithmetic.storage(callback, &work)
        try PoseIKArithmetic.charge(try PoseIKArithmetic.sum(try PoseIKArithmetic.product(32, square), try PoseIKArithmetic.product(32, tree.bodies.count+m)), &work)
        var identityBytes = 0
        func validateIdentity(_ string: String) throws(PoseIKError) {
            let count = string.utf8.prefix(policy.maximumIdentityBytes+1).count
            guard count > 0, count <= policy.maximumIdentityBytes else { throw .capacityExceeded }
            identityBytes = try PoseIKArithmetic.sum(identityBytes, count)
            guard identityBytes <= policy.maximumIdentityBytes else { throw .capacityExceeded }
        }
        try validateIdentity(problem.identity); try validateIdentity(tree.worldFrame.key)
        for body in tree.bodies { try validateIdentity(body.id.key); try validateIdentity(body.frame.key) }
        for joint in tree.joints {
            try validateIdentity(joint.id.key); try validateIdentity(joint.parentBody.key); try validateIdentity(joint.childBody.key)
            try validateIdentity(joint.parentAnchor.frame.key); try validateIdentity(joint.childAnchor.frame.key)
        }
        try PoseIKArithmetic.charge(identityBytes, &work)
        let treeIdentityBytes = identityBytes
        var expected: [PhysicalDimension] = []
        expected.reserveCapacity(n)
        for joint in tree.joints { for axis in joint.manifold.orderedAxes { expected.append(axis.kind == .prismatic ? .length : .angle) } }
        guard expected == layout.dimensions else { throw .invalidInput }
        for i in 0..<n {
            try PoseIKArithmetic.check(policy)
            guard layout.scales[i].isFinite, layout.scales[i] > 0,
                  !layout.coordinateIDs[..<i].contains(layout.coordinateIDs[i]),
                  problem.initialPositions[i].isFinite, problem.referencePositions[i].isFinite,
                  problem.minimumPositions[i].isFinite, problem.maximumPositions[i].isFinite,
                  problem.minimumPositions[i] <= problem.maximumPositions[i] else { throw .invalidInput }
            guard problem.initialPositions[i] >= problem.minimumPositions[i], problem.initialPositions[i] <= problem.maximumPositions[i],
                  problem.referencePositions[i] >= problem.minimumPositions[i], problem.referencePositions[i] <= problem.maximumPositions[i] else { throw .outsideBounds(coordinate: layout.coordinateIDs[i]) }
            _ = try PoseIKArithmetic.finite(problem.initialPositions[i]/layout.scales[i])
            _ = try PoseIKArithmetic.finite(problem.referencePositions[i]/layout.scales[i])
        }
        var ids: [UInt64] = []; ids.reserveCapacity(m)
        for task in problem.tasks {
            let body: EntityID, frame: EntityID, count: Int
            let scales: [Double], tolerances: [Double]
            switch task {
            case .point(_, let b, let f, _, _, let s, let t): body = b; frame = f; count = 3; scales = [s]; tolerances = [t]
            case .orientation(_, let b, let f, _, let s, let t): body = b; frame = f; count = 3; scales = [s]; tolerances = [t]
            case .pose(_, let b, let f, _, _, let s, let a, let t, let r): body = b; frame = f; count = 6; scales = [s,a]; tolerances = [t,r]
            // FIXME(INCOMPLETE_IMPLEMENTATION): PoseIKSolving.solve has no qualified collision/task derivative composition; collision cases fail before iteration until original geometry acceptance is implemented.
            case .collision: throw .unsupportedTask
            }
            guard task.rowIDs.count == count, scales.allSatisfy({ $0.isFinite && $0 > 0 }),
                  tolerances.allSatisfy({ $0.isFinite && $0 >= 0 }) else { throw .invalidInput }
            guard tree.bodies.contains(where: { $0.id == body && $0.frame == frame }) else { throw .staleIdentity }
            try validateIdentity(body.key); try validateIdentity(frame.key)
            for id in task.rowIDs { guard !ids.contains(id) else { throw .invalidInput }; ids.append(id) }
        }
        try PoseIKArithmetic.charge(identityBytes-treeIdentityBytes, &work)
        let ep: ConstraintEvaluationPolicy
        do {
            ep = try ConstraintEvaluationPolicy(maximumCoordinates: policy.maximumCoordinates, maximumRows: policy.maximumRows,
                expectedLayoutRevision: tree.revision, isCancelled: policy.isCancelled)
        } catch { throw .constraints(error) }
        if let loop = problem.loops {
            guard loop.layout.revision == layout.revision, loop.layout.coordinateIDs == layout.coordinateIDs,
                  loop.layout.dimensions == layout.dimensions, loop.layout.scales == layout.scales,
                  loop.layout.timeScale == layout.timeScale else { throw .staleIdentity }
            // The query's full box must lie inside the supplier's box; trial rejection never bypasses its bounds.
            for i in 0..<n {
                guard problem.minimumPositions[i] >= loop.minimumPosition[i],
                      problem.maximumPositions[i] <= loop.maximumPosition[i] else { throw .invalidInput }
            }
            for row in loop.rows { guard !ids.contains(row.id) else { throw .invalidInput }; ids.append(row.id) }
            do {
                _ = try QuadraticConstraintEvaluator().evaluate(loop, position: problem.initialPositions,
                    velocity: [Double](repeating: 0, count: n), time: problem.time, policy: ep, work: &work)
            } catch { throw .constraints(error) }
        }
        self.problem = problem; self.policy = policy; self.rows = ids
        self.solverCount = d; self.retainedStorage = retained; self.callbackStorage = callback
        self.evaluationPolicy = ep; self.cosineMargin = margin
    }

    func state(_ x: [Double], work: inout NumericalWork) throws(PoseIKError) -> KinematicState {
        try PoseIKArithmetic.check(policy)
        let n = problem.layout.scales.count
        guard x.count >= n else { throw .invalidShape }
        try PoseIKArithmetic.storage(callbackStorage, &work)
        try PoseIKArithmetic.charge(8*n, &work)
        var q = [Double](repeating: 0, count: n)
        for i in 0..<n {
            q[i] = try PoseIKArithmetic.finite(x[i]*problem.layout.scales[i])
            guard q[i] >= problem.minimumPositions[i], q[i] <= problem.maximumPositions[i] else { throw .outsideBounds(coordinate: problem.layout.coordinateIDs[i]) }
        }
        let zero = [Double](repeating: 0, count: n)
        do { return try KinematicState(revision: problem.tree.revision, time: problem.time, q: q, v: zero, acceleration: zero) }
        catch { throw .joints(error) }
    }
}
