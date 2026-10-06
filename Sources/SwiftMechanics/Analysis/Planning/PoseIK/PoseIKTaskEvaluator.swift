internal struct PoseIKTaskEvaluator: Sendable {
    let admission: PoseIKAdmission

    @inline(never)
    func evaluate(_ x: [Double], original: Bool, work: inout NumericalWork) throws(PoseIKError) -> PoseIKSample {
        let a = admission, p = a.problem, n = p.layout.scales.count, m = a.rows.count
        let state = try a.state(x, work: &work)
        // Tree arithmetic is owned by IM06; one invocation is explicitly charged here.
        try PoseIKArithmetic.charge(1, &work)
        let snapshot: KinematicSnapshot
        do { snapshot = try TreeKinematicsEvaluator().evaluate(p.tree, state: state, policy: a.policy.joint) }
        catch let error as JointError { throw .joints(error) }
        catch let error as CoreError { throw .core(error) }
        catch { throw .unexpectedSupplierFailure }
        var values = [Double](repeating: 0, count: m), jacobian = [Double](repeating: 0, count: m*n)
        var physical: [Double] = [], thresholds: [Double] = []
        physical.reserveCapacity(2*p.tasks.count); thresholds.reserveCapacity(2*p.tasks.count)
        var start = 0
        for task in p.tasks {
            try PoseIKArithmetic.check(a.policy)
            try PoseIKArithmetic.charge(256*(n+p.tree.bodies.count+1), &work)
            switch task {
            case .point(_, let body, _, let local, let target, let scale, let tolerance):
                try point(body, local, target, scale, tolerance, snapshot, original, start,
                    values: &values, jacobian: &jacobian, physical: &physical, thresholds: &thresholds)
            case .orientation(_, let body, _, let target, let scale, let tolerance):
                try orientation(body, target, scale, tolerance, snapshot, start,
                    values: &values, jacobian: &jacobian, physical: &physical, thresholds: &thresholds)
            case .pose(_, let body, _, let local, let target, let length, let angle, let pointTolerance, let orientationTolerance):
                try point(body, local, target.translation, length, pointTolerance, snapshot, original, start,
                    values: &values, jacobian: &jacobian, physical: &physical, thresholds: &thresholds)
                try orientation(body, target.rotation, angle, orientationTolerance, snapshot, start+3,
                    values: &values, jacobian: &jacobian, physical: &physical, thresholds: &thresholds)
            // FIXME(INCOMPLETE_IMPLEMENTATION): The actual PoseIK callback cannot evaluate collision rows; fail rather than substitute zero until geometry derivatives and original acceptance are qualified.
            case .collision: throw .unsupportedTask
            }
            start += task.rowIDs.count
        }
        var loopValues: [Double] = []
        if let loop = p.loops {
            let sample: ConstraintEvaluation
            do {
                sample = try QuadraticConstraintEvaluator().evaluate(loop, position: state.q, velocity: state.v,
                    time: state.time, policy: a.evaluationPolicy, work: &work)
            } catch { throw .constraints(error) }
            guard sample.rowIDs == loop.rows.map({ $0.id }), sample.layoutRevision == p.layout.revision,
                  sample.values.count == loop.rows.count, sample.jacobian.count == loop.rows.count*n else { throw .staleIdentity }
            loopValues = sample.values
            if original {
                // Independently recompute the immutable polynomial using H's triangular symmetry, not supplied values.
                let tau = state.time/p.layout.timeScale
                for row in loop.rows.indices {
                    try PoseIKArithmetic.check(a.policy)
                    try PoseIKArithmetic.charge(try PoseIKArithmetic.product(16, try PoseIKArithmetic.sum(try PoseIKArithmetic.product(n,n), n+1)), &work)
                    let r = loop.rows[row]
                    var value = r.constant+r.timeLinear*tau+0.5*r.timeQuadratic*tau*tau
                    for i in 0..<n {
                        value += (r.linear[i]+tau*r.mixedTime[i])*x[i]+0.5*r.hessian[i*n+i]*x[i]*x[i]
                        for j in 0..<i { value += r.hessian[i*n+j]*x[i]*x[j] }
                    }
                    loopValues[row] = try PoseIKArithmetic.finite(value)
                }
            }
            for r in loop.rows.indices {
                values[start+r] = loopValues[r]
                for j in 0..<n { jacobian[(start+r)*n+j] = sample.jacobian[r*n+j] }
            }
        }
        guard values.allSatisfy({ $0.isFinite }), jacobian.allSatisfy({ $0.isFinite }),
              physical.allSatisfy({ $0.isFinite }) else { throw .nonFiniteResult }
        try PoseIKArithmetic.check(a.policy)
        return PoseIKSample(state: state, snapshot: snapshot, values: values, jacobian: jacobian,
            physicalErrors: physical, physicalThresholds: thresholds, loopValues: loopValues)
    }

    private func body(_ id: EntityID, _ snapshot: KinematicSnapshot) throws(PoseIKError) -> BodyKinematics {
        do { return try snapshot.body(id) } catch { throw .joints(error) }
    }
    private func columns(_ id: EntityID, _ snapshot: KinematicSnapshot) throws(PoseIKError) -> ArraySlice<SpatialMotion> {
        do { return try snapshot.geometricColumns(body: id) } catch { throw .joints(error) }
    }
    private func point(_ id: EntityID, _ local: Vector3, _ target: Vector3, _ scale: Double, _ tolerance: Double,
                       _ snapshot: KinematicSnapshot, _ original: Bool, _ start: Int, values: inout [Double],
                       jacobian: inout [Double], physical: inout [Double], thresholds: inout [Double]) throws(PoseIKError) {
        let n = admission.problem.layout.scales.count
        let motion = try body(id, snapshot), cols = try columns(id, snapshot)
        let offset = try PoseIKArithmetic.geometry { () throws(CoreError) in try motion.motion.pose.rotation.rotating(local) }
        let point: Vector3
        if original {
            let rotation = try PoseIKArithmetic.geometry { () throws(CoreError) in try motion.motion.pose.rotation.matrix() }
            point = try PoseIKArithmetic.geometry { () throws(CoreError) in try rotation.applying(to: local).adding(motion.motion.pose.translation) }
        } else {
            point = try PoseIKArithmetic.geometry { () throws(CoreError) in try motion.motion.pose.translation.adding(offset) }
        }
        let error = try PoseIKArithmetic.geometry { () throws(CoreError) in try point.subtracting(target) }
        physical.append(try PoseIKArithmetic.geometry { () throws(CoreError) in try error.magnitude() }); thresholds.append(tolerance)
        for r in 0..<3 { values[start+r] = try PoseIKArithmetic.finite(PoseIKArithmetic.component(error,r)/scale) }
        for j in 0..<n {
            let c = cols[cols.startIndex+j]
            let value = try PoseIKArithmetic.geometry { () throws(CoreError) in try c.linear.adding(c.angular.cross(offset)) }
            for r in 0..<3 { jacobian[(start+r)*n+j] = try PoseIKArithmetic.finite(PoseIKArithmetic.component(value,r)*admission.problem.layout.scales[j]/scale) }
        }
    }
    private func orientation(_ id: EntityID, _ target: UnitQuaternion, _ scale: Double, _ tolerance: Double,
                             _ snapshot: KinematicSnapshot, _ start: Int, values: inout [Double],
                             jacobian: inout [Double], physical: inout [Double], thresholds: inout [Double]) throws(PoseIKError) {
        let n = admission.problem.layout.scales.count, motion = try body(id, snapshot), cols = try columns(id, snapshot)
        let r = try PoseIKArithmetic.geometry { () throws(CoreError) in try motion.motion.pose.rotation.matrix() }
        let rt = try PoseIKArithmetic.geometry { () throws(CoreError) in try target.matrix() }, qt = rt.transposed()
        let e = try PoseIKArithmetic.geometry { () throws(CoreError) in try qt.multiplied(by: r) }
        let cosine = try PoseIKArithmetic.finite((e.m00+e.m11+e.m22-1)/2)
        // FIXME(INCOMPLETE_IMPLEMENTATION): PoseIKSolving.solve has no orientation chart outside the supplied acute-angle branch; refuse until branch-safe full-range orientation residuals and derivatives are qualified.
        guard cosine > admission.cosineMargin else { throw .orientationBranch(row: admission.rows[start], cosine: cosine) }
        let residual = try PoseIKArithmetic.vee(e)
        let difference = try PoseIKArithmetic.geometry { () throws(CoreError) in try r.subtracting(rt) }
        var squared = 0.0
        for i in 0..<3 { for j in 0..<3 {
            let value = try PoseIKArithmetic.geometry { () throws(CoreError) in try difference.element(row:i,column:j) }; squared += value*value
        } }
        physical.append(try PoseIKArithmetic.finite(squared.squareRoot())); thresholds.append(tolerance)
        for i in 0..<3 { values[start+i] = try PoseIKArithmetic.finite(PoseIKArithmetic.component(residual,i)/scale) }
        for j in 0..<n {
            let skew = try PoseIKArithmetic.skew(cols[cols.startIndex+j].angular)
            let matrix = try PoseIKArithmetic.geometry { () throws(CoreError) in try qt.multiplied(by: skew).multiplied(by: r) }
            let column = try PoseIKArithmetic.vee(matrix)
            for i in 0..<3 { jacobian[(start+i)*n+j] = try PoseIKArithmetic.finite(PoseIKArithmetic.component(column,i)*admission.problem.layout.scales[j]/scale) }
        }
    }
}
