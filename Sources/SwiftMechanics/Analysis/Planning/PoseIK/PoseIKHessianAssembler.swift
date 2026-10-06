internal struct PoseIKHessianAssembler: Sendable {
    let admission: PoseIKAdmission

    @inline(never)
    func add(_ sample: PoseIKSample, multipliers: ArraySlice<Double>, into matrix: inout [Double],
             work: inout NumericalWork) throws(PoseIKError) {
        let a = admission, p = a.problem, n = p.layout.scales.count, d = a.solverCount
        guard multipliers.count == a.rows.count else { throw .invalidShape }
        var workspace = TreeTangentWorkspace()
        let zero = [Double](repeating: 0, count: n)
        var direction = zero
        for k in 0..<n {
            try PoseIKArithmetic.check(a.policy)
            do { try work.advanceIteration() } catch { throw .numerical(error) }
            try PoseIKArithmetic.charge(8*n, &work)
            if k > 0 { direction[k-1] = 0 }; direction[k] = p.layout.scales[k]
            let input = TreeDirection(revision: p.tree.revision, configuration: direction, velocity: zero,
                acceleration: zero, screwPitch: zero)
            let tangent: TreeTangent
            do {
                var supplier = try DerivativeSupplierWork(maximumCalls: a.policy.maximumDerivativeCallsPerDirection)
                tangent = try ExactTreeDifferentiator().direction(p.tree, state: sample.state, direction: input,
                    jointPolicy: a.policy.joint, policy: a.policy.derivative, workspace: &workspace,
                    supplierWork: &supplier, work: &work)
            } catch { throw .derivatives(error) }
            guard tangent.bodies.count == p.tree.bodies.count, tangent.geometricColumns.count == n*p.tree.bodies.count else { throw .invalidShape }
            var start = 0
            for task in p.tasks {
                try PoseIKArithmetic.check(a.policy)
                try PoseIKArithmetic.charge(512*(n+p.tree.bodies.count+1), &work)
                switch task {
                case .point(_, let body, _, let local, _, let scale, _):
                    try point(body, local, scale, sample, tangent, multipliers, start, k, &matrix)
                case .orientation(_, let body, _, let target, let scale, _):
                    try orientation(body, target, scale, sample, tangent, multipliers, start, k, &matrix)
                case .pose(_, let body, _, let local, let target, let length, let angle, _, _):
                    try point(body, local, length, sample, tangent, multipliers, start, k, &matrix)
                    try orientation(body, target.rotation, angle, sample, tangent, multipliers, start+3, k, &matrix)
                // FIXME(INCOMPLETE_IMPLEMENTATION): PoseIK KKT Hessians have no collision derivative supplier; this branch refuses until actual collision products and original acceptance are qualified.
                case .collision: throw .unsupportedTask
                }
                start += task.rowIDs.count
            }
            if let loops = p.loops {
                try PoseIKArithmetic.charge(try PoseIKArithmetic.product(4, try PoseIKArithmetic.product(loops.rows.count,n)), &work)
                for r in loops.rows.indices {
                    let lambda = multipliers[multipliers.startIndex+start+r]
                    for j in 0..<n {
                        matrix[j*d+k] = try PoseIKArithmetic.finite(matrix[j*d+k]+lambda*loops.rows[r].hessian[j*n+k])
                    }
                }
            }
        }
    }

    private func bodyIndex(_ id: EntityID) throws(PoseIKError) -> Int {
        do { return try admission.problem.tree.bodyIndex(id) } catch { throw .joints(error) }
    }
    private func columns(_ id: EntityID, _ snapshot: KinematicSnapshot) throws(PoseIKError) -> ArraySlice<SpatialMotion> {
        do { return try snapshot.geometricColumns(body: id) } catch { throw .joints(error) }
    }
    private func point(_ id: EntityID, _ local: Vector3, _ scale: Double, _ sample: PoseIKSample,
                       _ tangent: TreeTangent, _ multipliers: ArraySlice<Double>, _ start: Int, _ k: Int,
                       _ matrix: inout [Double]) throws(PoseIKError) {
        let p = admission.problem, n = p.layout.scales.count, d = admission.solverCount, b = try bodyIndex(id)
        let pose = sample.snapshot.bodies[b].motion.pose, delta = tangent.bodies[b]
        let offset = try PoseIKArithmetic.geometry { () throws(CoreError) in try pose.rotation.rotating(local) }
        let deltaOffset = try PoseIKArithmetic.geometry { () throws(CoreError) in try delta.rotationMatrix.applying(to: local) }
        let cols = try columns(id, sample.snapshot)
        for j in 0..<n {
            let c = cols[cols.startIndex+j], dc = tangent.geometricColumns[b*n+j]
            let derivative = try PoseIKArithmetic.geometry { () throws(CoreError) in
                try dc.linear.adding(dc.angular.cross(offset)).adding(c.angular.cross(deltaOffset))
            }
            var contribution = 0.0
            for r in 0..<3 { contribution += multipliers[multipliers.startIndex+start+r]*PoseIKArithmetic.component(derivative,r)*p.layout.scales[j]/scale }
            matrix[j*d+k] = try PoseIKArithmetic.finite(matrix[j*d+k]+contribution)
        }
    }
    private func orientation(_ id: EntityID, _ target: UnitQuaternion, _ scale: Double, _ sample: PoseIKSample,
                             _ tangent: TreeTangent, _ multipliers: ArraySlice<Double>, _ start: Int, _ k: Int,
                             _ matrix: inout [Double]) throws(PoseIKError) {
        let p = admission.problem, n = p.layout.scales.count, d = admission.solverCount, b = try bodyIndex(id)
        let r = try PoseIKArithmetic.geometry { () throws(CoreError) in try sample.snapshot.bodies[b].motion.pose.rotation.matrix() }
        let qt = try PoseIKArithmetic.geometry { () throws(CoreError) in try target.matrix().transposed() }
        let dr = tangent.bodies[b].rotationMatrix, cols = try columns(id, sample.snapshot)
        for j in 0..<n {
            let w = try PoseIKArithmetic.skew(cols[cols.startIndex+j].angular)
            let dw = try PoseIKArithmetic.skew(tangent.geometricColumns[b*n+j].angular)
            let second = try PoseIKArithmetic.geometry { () throws(CoreError) in try qt.multiplied(by: dw.multiplied(by: r).adding(w.multiplied(by: dr))) }
            let derivative = try PoseIKArithmetic.vee(second)
            var contribution = 0.0
            for row in 0..<3 { contribution += multipliers[multipliers.startIndex+start+row]*PoseIKArithmetic.component(derivative,row)*p.layout.scales[j]/scale }
            matrix[j*d+k] = try PoseIKArithmetic.finite(matrix[j*d+k]+contribution)
        }
    }
}
