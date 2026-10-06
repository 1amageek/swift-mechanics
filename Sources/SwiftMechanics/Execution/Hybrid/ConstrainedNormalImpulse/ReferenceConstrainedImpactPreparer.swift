@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ReferenceConstrainedImpactPreparer: ConstrainedImpactPreparing {
    private let equations: any RigidEquationComputing
    private let evaluator: any ConstraintEvaluating
    private let rank: any ConstraintRankAnalyzing
    public init(equations: any RigidEquationComputing = RigidEquationKernel(),
                evaluator: any ConstraintEvaluating = QuadraticConstraintEvaluator(),
                rank: any ConstraintRankAnalyzing = WeightedConstraintAssembler()) {
        self.equations = equations; self.evaluator = evaluator; self.rank = rank
    }
    @inline(never)
    public func prepare(input: HardImpactInput, constraints: QuadraticConstraintSystem, policy: ConstrainedImpactPolicy,
                        admission: DynamicsAdmission, loadWork: inout LoadWork, work: inout NumericalWork,
                        cancellation: HybridCancellation) throws(ConstrainedImpactError) -> PreparedConstrainedImpact {
        try ConstrainedImpactArithmetic.check(cancellation)
        let reserved = try preflight(input,constraints:constraints,policy:policy,work:&work)
        let impact = try prepareImpact(input,policy:policy,admission:admission,reserved:reserved,loadWork:&loadWork,work:&work,cancellation:cancellation)
        let rows = try prepareRows(input,constraints:constraints,policy:policy,
            reserved:ConstrainedImpactArithmetic.sum(reserved,impact.system.scalarStorage),work:&work)
        try ConstrainedImpactArithmetic.check(cancellation)
        return PreparedConstrainedImpact(source:input,impact:impact,constraints:constraints,policy:policy,
                                         rowIDs:constraints.rows.map({ $0.id }),rows:rows)
    }
    @inline(never)
    private func preflight(_ input: HardImpactInput, constraints: QuadraticConstraintSystem,
                           policy: ConstrainedImpactPolicy, work: inout NumericalWork) throws(ConstrainedImpactError) -> Int {
        let n = input.model.tree.layout.velocityCount, m = constraints.rows.count
        guard n > 0, n <= policy.impact.maximumVelocities, n <= policy.constraints.evaluation.maximumCoordinates,
              m > 0, m <= policy.constraints.evaluation.maximumRows,
              input.model.tree.bodies.count <= policy.impact.maximumBodies,
              input.inertias.count <= policy.impact.maximumBodies,
              input.collision.proxies.count <= policy.impact.maximumColliders,
              input.contacts.count <= policy.impact.maximumContacts else { throw ConstrainedImpactError(.capacityExceeded) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): This lower solver currently admits one analytic closing contact.
        // A genuine multi-contact complementarity/law/energy solution is required before that domain can succeed.
        guard input.contacts.count == 1 else { throw ConstrainedImpactError(.unsupportedDomain) }
        let square = try ConstrainedImpactArithmetic.product(n,n)
        let total = try ConstrainedImpactArithmetic.sum(m,1)
        let augmented = try ConstrainedImpactArithmetic.product(total,total)
        guard square <= policy.maximumFactorEntries, augmented <= policy.maximumFactorEntries else {
            throw ConstrainedImpactError(.capacityExceeded)
        }
        let storage = try ConstrainedImpactArithmetic.sum(square,try ConstrainedImpactArithmetic.sum(
            try ConstrainedImpactArithmetic.product(m,square),try ConstrainedImpactArithmetic.product(12,try ConstrainedImpactArithmetic.sum(n,m))))
        try ConstrainedImpactArithmetic.storage(storage,&work)
        guard input.physical.stamp == input.model.stamp, input.physical.state.q.count == n,
              input.physical.state.v.count == n, constraints.layout.scales.count == n,
              constraints.layout.revision == input.model.stamp.revision,
              constraints.layout.revision == policy.constraints.evaluation.expectedLayoutRevision,
              constraints.layout.scales == policy.dynamics.coordinateScales,
              constraints.layout.timeScale == policy.dynamics.timeScale,
              policy.impact.impulseScales.count == n else { throw ConstrainedImpactError(.sourceMismatch) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Floating/manifold and prescribed retained constraints reach this admission.
        // Their instantaneous chart, boundary impulse/work and original source acceptance must precede success.
        guard input.model.tree.rootBase == .fixed, input.model.descriptor.rootAuthority == .fixed,
              input.model.tree.layout.positionCount == n else { throw ConstrainedImpactError(.unsupportedDomain) }
        for entry in input.model.tree.layout.joints {
            try ConstrainedImpactArithmetic.charge(1,&work)
            guard entry.positions.count == 1, entry.velocities.count == 1, entry.positions.start == entry.velocities.start,
                  let joint = input.model.descriptor.joints.first(where:{ $0.record.id == entry.joint }),
                  joint.authority == .dynamicState,
                  joint.record.manifold.kind == .revolute || joint.record.manifold.kind == .prismatic,
                  constraints.layout.dimensions[entry.velocities.start] == (joint.record.manifold.kind == .revolute ? .angle : .length) else {
                throw ConstrainedImpactError(.unsupportedDomain)
            }
            for anchor in [joint.record.parentAnchor,joint.record.childAnchor] {
                if case .prescribed = anchor.placement { throw ConstrainedImpactError(.unsupportedDomain) }
            }
        }
        guard input.inertias.count == input.model.tree.bodies.count else { throw ConstrainedImpactError(.sourceMismatch) }
        for i in input.model.tree.bodies.indices {
            let body = input.model.tree.bodies[i]
            try ConstrainedImpactArithmetic.charge(input.model.descriptor.bodies.count,&work)
            guard let descriptor = input.model.descriptor.bodies.first(where:{ $0.id == body.id }),
                  case .spatial(let spatial) = descriptor, let inertia = spatial.inertia,
                  input.inertias[i].body == body.id, input.inertias[i].frame == body.frame,
                  input.inertias[i].properties == inertia.properties else { throw ConstrainedImpactError(.sourceMismatch) }
        }
        for row in constraints.rows {
            guard row.linear.count == n, row.hessian.count == square, row.mixedTime.count == n else {
                throw ConstrainedImpactError(.invalidInput)
            }
            try ConstrainedImpactArithmetic.charge(try ConstrainedImpactArithmetic.sum(square,try ConstrainedImpactArithmetic.product(2,n)),&work)
            // FIXME(INCOMPLETE_IMPLEMENTATION): Nonlinear or time-dependent retained equations reach this port.
            // Original instantaneous impulse and boundary-energy acceptance is required before extending this stationary domain.
            guard row.hessian.allSatisfy({ $0 == 0 }), row.mixedTime.allSatisfy({ $0 == 0 }),
                  row.timeLinear == 0, row.timeQuadratic == 0 else { throw ConstrainedImpactError(.unsupportedDomain) }
        }
        return storage
    }
    @inline(never)
    private func prepareImpact(_ input: HardImpactInput, policy: ConstrainedImpactPolicy, admission: DynamicsAdmission, reserved: Int,
                               loadWork: inout LoadWork, work: inout NumericalWork,
                               cancellation: HybridCancellation) throws(ConstrainedImpactError) -> PreparedImpact {
        let receipt = ConstrainedImpactAssemblyReceipt()
        let adapter = RigidHardImpactAdapter(equations:ConstrainedImpactRigidSupplier(base:equations,receipt:receipt))
        var local = try ConstrainedImpactInvocation.local(work,reserved:reserved)
        let result: PreparedImpact
        do throws(ConstrainedImpactError) {
            result = try ConstrainedImpactInvocation.assembly(load:&loadWork,work:&local) { (load: inout LoadWork, numerical: inout NumericalWork) throws(ConstrainedImpactError) in
                do throws(HybridError) { return try adapter.prepare(input,policy:policy.impact,admission:admission,loadWork:&load,work:&numerical,cancellation:cancellation) }
                catch {
                    if let failure = receipt.failure { throw failure }
                    throw ConstrainedImpactError(.hybrid(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable)
                }
            }
        } catch { try ConstrainedImpactInvocation.absorb(local,into:&work,reserved:reserved); throw error }
        try ConstrainedImpactInvocation.absorb(local,into:&work,reserved:reserved)
        guard result.model == input.model.stamp, result.system.input.velocity == input.physical.state.v,
              result.system.input.inertias == input.inertias, result.system.input.snapshot.time == input.physical.state.time,
              result.system.input.snapshot.tree.layout == input.model.tree.layout,
              result.normalRows.count == input.physical.state.v.count else { throw ConstrainedImpactError(.sourceMismatch) }
        return result
    }
    @inline(never)
    private func prepareRows(_ input: HardImpactInput, constraints: QuadraticConstraintSystem,
                             policy: ConstrainedImpactPolicy, reserved: Int, work: inout NumericalWork) throws(ConstrainedImpactError) -> [Double] {
        var local = try ConstrainedImpactInvocation.local(work,reserved:reserved)
        let evaluation: ConstraintEvaluation
        do throws(ConstrainedImpactError) {
            evaluation = try ConstrainedImpactInvocation.numerical(work:&local) { (numerical: inout NumericalWork) throws(ConstrainedImpactError) in
                do throws(ConstraintError) { return try evaluator.evaluate(constraints,position:input.physical.state.q,velocity:input.physical.state.v,
                    time:input.physical.state.time,policy:policy.constraints.evaluation,work:&numerical) }
                catch { throw ConstrainedImpactError(.constraint(error),failedSupplierWorkUnavailable:ConstrainedImpactArithmetic.unavailable(.constraint(error))) }
            }
        } catch { try ConstrainedImpactInvocation.absorb(local,into:&work,reserved:reserved); throw error }
        try ConstrainedImpactInvocation.absorb(local,into:&work,reserved:reserved)
        let n = input.physical.state.v.count, m = constraints.rows.count
        let mn = try ConstrainedImpactArithmetic.product(m,n)
        guard evaluation.layoutRevision == constraints.layout.revision, evaluation.values.count == m,
              evaluation.jacobian.count == mn, evaluation.normalizedVelocity.count == n,
              evaluation.normalizedPosition.count == n, evaluation.timeDerivative.count == m,
              evaluation.accelerationBias.count == m, evaluation.rowIDs == constraints.rows.map({ $0.id }) else {
            throw ConstrainedImpactError(.sourceMismatch)
        }
        var physicalRows = [Double](repeating:0,count:mn)
        for r in 0..<m {
            var velocity = 0.0, position = constraints.rows[r].constant
            for k in 0..<n {
                try ConstrainedImpactArithmetic.charge(9,&work)
                let scale = constraints.layout.scales[k]
                guard scale.isFinite, scale > 0,
                      evaluation.jacobian[r*n+k] == constraints.rows[r].linear[k],
                      evaluation.normalizedPosition[k] == input.physical.state.q[k]/scale,
                      evaluation.normalizedVelocity[k] == input.physical.state.v[k]*constraints.layout.timeScale/scale else {
                    throw ConstrainedImpactError(.sourceMismatch)
                }
                physicalRows[r*n+k] = try ConstrainedImpactArithmetic.finite(evaluation.jacobian[r*n+k]/scale)
                velocity = try ConstrainedImpactArithmetic.finite(velocity+evaluation.jacobian[r*n+k]*evaluation.normalizedVelocity[k])
                position = try ConstrainedImpactArithmetic.finite(position+constraints.rows[r].linear[k]*evaluation.normalizedPosition[k])
            }
            guard evaluation.timeDerivative[r] == 0, evaluation.accelerationBias[r] == 0,
                  evaluation.values[r] == position, abs(position) <= policy.constraints.originalResidualTolerance,
                  abs(velocity) <= policy.constraints.originalResidualTolerance else { throw ConstrainedImpactError(.residualRejected) }
        }
        try fullRank(VelocityConstraintSample(layout:constraints.layout,holonomic:evaluation),policy:policy,reserved:reserved,work:&work)
        return physicalRows
    }
    @inline(never)
    private func fullRank(_ sample: VelocityConstraintSample, policy: ConstrainedImpactPolicy, reserved: Int,
                          work: inout NumericalWork) throws(ConstrainedImpactError) {
        var local = try ConstrainedImpactInvocation.local(work,reserved:reserved)
        let evidence: ConstraintRankEvidence
        do throws(ConstrainedImpactError) {
            evidence = try ConstrainedImpactInvocation.numerical(work:&local) { (numerical: inout NumericalWork) throws(ConstrainedImpactError) in
                do throws(ConstraintError) { return try rank.rank(sample,policy:policy.constraints,work:&numerical) }
                catch { throw ConstrainedImpactError(.constraint(error),failedSupplierWorkUnavailable:ConstrainedImpactArithmetic.unavailable(.constraint(error))) }
            }
        } catch { try ConstrainedImpactInvocation.absorb(local,into:&work,reserved:reserved); throw error }
        try ConstrainedImpactInvocation.absorb(local,into:&work,reserved:reserved)
        let m = sample.rowIDs.count
        // FIXME(INCOMPLETE_IMPLEMENTATION): Redundant retained rows cannot issue unique retained impulse allocations here.
        // An explicit set-valued/allocation authority is required before that domain can succeed.
        guard evidence.rank == m, evidence.reactionNullity == 0, evidence.dependentRowIDs.isEmpty,
              evidence.independentRows.count == m else { throw ConstrainedImpactError(.rankAmbiguity(rank:evidence.rank,rows:m)) }
        for i in evidence.independentRows.indices {
            try ConstrainedImpactArithmetic.charge(m,&work)
            guard evidence.independentRows[i] >= 0, evidence.independentRows[i] < m,
                  !evidence.independentRows[..<i].contains(evidence.independentRows[i]) else { throw ConstrainedImpactError(.sourceMismatch) }
        }
    }
}
