@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension ReferenceConstrainedNormalImpulseSolver {
    @inline(never)
    internal func accept(_ candidate: ConstrainedImpactCandidate, work: inout NumericalWork,
                         cancellation: HybridCancellation) throws(ConstrainedImpactError) -> ConstrainedNormalImpulseResult {
        let source = candidate.mode.workspace.source, policy = source.policy.impact
        let momentum = try momentumResidual(candidate,work:&work)
        let constraint = try constraintResidual(candidate,work:&work)
        let law = try ConstrainedImpactArithmetic.finite(abs(candidate.after-candidate.prediction.reboundSpeed))
        let before = try kineticEnergy(source,velocity:source.impact.system.input.velocity,reserved:candidate.mode.workspace.reserved,work:&work)
        let after = try kineticEnergy(source,velocity:candidate.velocity,reserved:candidate.mode.workspace.reserved,work:&work)
        let energy = try ConstrainedImpactArithmetic.finite(abs(before-after-candidate.prediction.lostNormalEnergy))
        let limit = try ConstrainedImpactArithmetic.finite(policy.energyAbsolute+policy.energyRelative*max(abs(before),abs(after)))
        guard law <= policy.speedTolerance, before >= -policy.energyAbsolute, after >= -policy.energyAbsolute,
              after <= before+limit, energy <= limit else { throw ConstrainedImpactError(.residualRejected) }
        try ConstrainedImpactArithmetic.check(cancellation)
        return ConstrainedNormalImpulseResult(source:source,candidate:candidate,energyBefore:before,energyAfter:after,
            momentum:momentum,constraint:constraint,law:law,energy:energy)
    }
    @inline(never)
    private func momentumResidual(_ candidate: ConstrainedImpactCandidate, work: inout NumericalWork) throws(ConstrainedImpactError) -> Double {
        let source = candidate.mode.workspace.source, policy = source.policy.impact
        let original = try originalAction(source,values:candidate.delta,reserved:candidate.mode.workspace.reserved,work:&work)
        try ConstrainedImpactArithmetic.charge(try ConstrainedImpactArithmetic.product(6,original.count),&work)
        var residual = 0.0, scale = 0.0
        for i in original.indices {
            residual = max(residual,try ConstrainedImpactArithmetic.finite(abs(original[i]-candidate.applied[i])/policy.impulseScales[i]))
            scale = max(scale,try ConstrainedImpactArithmetic.finite(max(abs(original[i]),abs(candidate.applied[i]))/policy.impulseScales[i]))
        }
        let limit = try ConstrainedImpactArithmetic.finite(policy.momentumAbsolute+policy.momentumRelative*scale)
        guard residual <= limit else { throw ConstrainedImpactError(.residualRejected) }
        return residual
    }
    @inline(never)
    private func constraintResidual(_ candidate: ConstrainedImpactCandidate, work: inout NumericalWork) throws(ConstrainedImpactError) -> Double {
        let source = candidate.mode.workspace.source
        var residual = 0.0
        for r in source.retainedRowIDs.indices {
            let row = physicalRow(source,index:r)
            let value = try ConstrainedImpactArithmetic.dot(row,candidate.velocity,work:&work)
            residual = max(residual,try ConstrainedImpactArithmetic.finite(abs(value)*source.constraints.layout.timeScale))
        }
        guard residual <= source.policy.constraints.originalResidualTolerance else { throw ConstrainedImpactError(.residualRejected) }
        return residual
    }
    @inline(never)
    private func kineticEnergy(_ source: PreparedConstrainedImpact, velocity: [Double], reserved: Int,
                               work: inout NumericalWork) throws(ConstrainedImpactError) -> Double {
        let mass = try originalAction(source,values:velocity,reserved:reserved,work:&work)
        return try ConstrainedImpactArithmetic.finite(0.5*ConstrainedImpactArithmetic.dot(velocity,mass,work:&work))
    }
}
