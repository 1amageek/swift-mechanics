internal enum MechanicalEstimatorPropagation {
    @inline(never)
    static func propagate(_ checkpoint: NonlinearEstimatorCheckpoint, request: NonlinearEstimatorRequest,
                          policy: NonlinearEstimatorPolicy, calls: inout DerivativeSupplierWork,
                          work: inout NumericalWork) throws(NonlinearEstimatorCause) -> EstimatorPropagationState {
        var state = EstimatorPropagationState(time: checkpoint.timeSeconds, position: checkpoint.positionMeters,
            rate: checkpoint.rateMetersPerSecond, transition: .identity)
        if request.targetTimeSeconds == checkpoint.timeSeconds { return state }
        let interval = request.targetTimeSeconds-checkpoint.timeSeconds
        for i in 0..<request.substeps {
            try EstimatorArithmetic.charge(512, policy: policy, work: &work)
            do { try work.advanceIteration() } catch { throw .numerical(error) }
            let target = i+1 == request.substeps ? request.targetTimeSeconds
                : checkpoint.timeSeconds+interval*Double(i+1)/Double(request.substeps)
            state = try step(state, to: target, plant: checkpoint.plant, effort: request.heldEffortNewtons,
                             policy: policy, calls: &calls, work: &work)
        }
        return state
    }

    @inline(never)
    private static func step(_ x: EstimatorPropagationState, to target: Double, plant: PrismaticEstimationModel,
                             effort: Double, policy: NonlinearEstimatorPolicy, calls: inout DerivativeSupplierWork,
                             work: inout NumericalWork) throws(NonlinearEstimatorCause) -> EstimatorPropagationState {
        let h = target-x.time, middle = x.time+h/2
        guard h.isFinite, h > 0, middle > x.time, middle < target else { throw .invalidInput }
        let s1 = try plant.sample(time: x.time, position: x.position, rate: x.rate, effort: effort, policy: policy, calls: &calls, work: &work)
        let f1 = try field(s1, plant: plant).multiplying(x.transition)
        let v2 = try EstimatorArithmetic.finite(x.rate+h*s1.acceleration/2), p2 = try x.transition.adding(f1.scaled(h/2))
        let s2 = try plant.sample(time: middle, position: x.position+h*x.rate/2, rate: v2, effort: effort, policy: policy, calls: &calls, work: &work)
        let f2 = try field(s2, plant: plant).multiplying(p2)
        let v3 = try EstimatorArithmetic.finite(x.rate+h*s2.acceleration/2), p3 = try x.transition.adding(f2.scaled(h/2))
        let s3 = try plant.sample(time: middle, position: x.position+h*v2/2, rate: v3, effort: effort, policy: policy, calls: &calls, work: &work)
        let f3 = try field(s3, plant: plant).multiplying(p3)
        let v4 = try EstimatorArithmetic.finite(x.rate+h*s3.acceleration), p4 = try x.transition.adding(f3.scaled(h))
        let s4 = try plant.sample(time: target, position: x.position+h*v3, rate: v4, effort: effort, policy: policy, calls: &calls, work: &work)
        let f4 = try field(s4, plant: plant).multiplying(p4)
        let sum = try f1.adding(f2.scaled(2)).adding(f3.scaled(2)).adding(f4)
        let final = EstimatorPropagationState(time: target, position: try EstimatorArithmetic.finite(x.position+h*(x.rate+2*v2+2*v3+v4)/6),
            rate: try EstimatorArithmetic.finite(x.rate+h*(s1.acceleration+2*s2.acceleration+2*s3.acceleration+s4.acceleration)/6),
            transition: try x.transition.adding(sum.scaled(h/6)))
        try plant.domain(position: final.position, rate: final.rate, policy: policy)
        return final
    }
    private static func field(_ sample: EstimatorMechanicalSample, plant: PrismaticEstimationModel) throws(NonlinearEstimatorCause) -> EstimatorMatrix2 {
        try EstimatorMatrix2(a: 0,b: plant.rateScaleMetersPerSecond/plant.positionScaleMeters,
            c: sample.coordinateDerivative*plant.positionScaleMeters/plant.rateScaleMetersPerSecond,d: sample.rateDerivative).checked()
    }
}
