internal enum PoseIKOriginalAcceptance {
    static func evidence(_ sample: PoseIKSample, admission: PoseIKAdmission, rank: ConstraintRankEvidence? = nil,
                         work: inout NumericalWork) throws(PoseIKError) -> PoseIKEvidence {
        let p = admission.problem, n = p.layout.scales.count
        try PoseIKArithmetic.charge(try PoseIKArithmetic.product(12,n+sample.physicalErrors.count+sample.loopValues.count), &work)
        var slack = Double.infinity
        for i in 0..<n {
            slack = min(slack, (sample.state.q[i]-p.minimumPositions[i])/p.layout.scales[i])
            slack = min(slack, (p.maximumPositions[i]-sample.state.q[i])/p.layout.scales[i])
        }
        _ = try PoseIKArithmetic.finite(slack)
        var feasible = slack >= 0 && rank != nil
        for i in sample.physicalErrors.indices {
            feasible = feasible && sample.physicalErrors[i] <= sample.physicalThresholds[i]
        }
        for value in sample.loopValues { feasible = feasible && abs(value) <= admission.policy.loopTolerance }
        if let rank { feasible = feasible && rank.rank == admission.rows.count }
        return PoseIKEvidence(rowIDs: admission.rows, originalNormalizedResiduals: sample.values,
            physicalTaskErrors: sample.physicalErrors, physicalTaskThresholds: sample.physicalThresholds,
            loopRowIDs: p.loops?.rows.map({ $0.id }) ?? [], originalLoopResiduals: sample.loopValues,
            minimumBoundSlack: slack, rowRank: rank, isFeasible: feasible)
    }

    static func reject(_ evidence: PoseIKEvidence, admission: PoseIKAdmission) throws(PoseIKError) {
        var index = 0
        for task in admission.problem.tasks {
            let count = task.rowIDs.count == 6 ? 2 : 1
            for k in 0..<count {
                let residual = evidence.physicalTaskErrors[index], threshold = evidence.physicalTaskThresholds[index]
                guard residual <= threshold else {
                    throw .originalTaskRejected(row: task.rowIDs[k*3], residual: residual, threshold: threshold)
                }
                index += 1
            }
        }
        for i in evidence.originalLoopResiduals.indices {
            let value = abs(evidence.originalLoopResiduals[i])
            guard value <= admission.policy.loopTolerance else {
                throw .originalLoopRejected(row: evidence.loopRowIDs[i], residual: value, threshold: admission.policy.loopTolerance)
            }
        }
        guard evidence.minimumBoundSlack >= 0 else { throw .invalidInput }
    }

    static func rank(_ sample: PoseIKSample, admission: PoseIKAdmission, work: inout NumericalWork) throws(PoseIKError) -> ConstraintRankEvidence {
        let p = admission.problem, n = p.layout.scales.count, m = admission.rows.count
        let zero = [Double](repeating: 0, count: m)
        let rows = VelocityConstraintSample(layout: p.layout, rowIDs: admission.rows, rows: sample.jacobian,
            drift: zero, accelerationBias: zero, isIntegrable: true)
        let policy: ConstraintSolvePolicy
        do {
            policy = try ConstraintSolvePolicy(evaluation: admission.evaluationPolicy, diagonalMetric: [Double](repeating:1,count:n),
                energyScale: 1, rankPolicy: .allowRedundancy, rankRelativeTolerance: admission.policy.rankRelativeTolerance,
                originalResidualTolerance: admission.policy.loopTolerance, maximumCorrection: 0,
                nonlinear: admission.policy.nonlinear, linearCapability: admission.policy.nonlinear.capability,
                linearTolerance: admission.policy.nonlinear.tolerance)
            return try WeightedConstraintAssembler().rank(rows, policy: policy, work: &work)
        } catch { throw .constraints(error) }
    }
}
