public struct ReferenceMechanicalEKF: NonlinearStateEstimating {
    public init() {}

    @inline(never)
    public func initialize(plant: PrismaticEstimationModel, timeSeconds: Double, positionMeters: Double,
                           rateMetersPerSecond: Double, normalizedCovariance: [Double], policy: NonlinearEstimatorPolicy,
                           work: inout NumericalWork) throws(NonlinearEstimatorFailure) -> NonlinearEstimatorCheckpoint {
        var phase = "initial-admission", calls: DerivativeSupplierWork
        do { calls = try DerivativeSupplierWork(maximumCalls: policy.maximumDerivativeCalls) }
        catch { throw NonlinearEstimatorFailure(cause: .derivatives(error), phase: phase, work: work, derivativeCalls: 0) }
        var nested: NumericalWork
        do {
            try EstimatorArithmetic.charge(256, policy: policy, work: &work)
            try EstimatorArithmetic.reserve(512, policy: policy, work: &work)
            nested = try EstimatorArithmetic.nested(work, reserved: 512, policy: policy)
        } catch { throw NonlinearEstimatorFailure(cause: error, phase: phase, work: work, derivativeCalls: calls.calls) }
        var result: NonlinearEstimatorCheckpoint?, failure: NonlinearEstimatorCause?
        do { result = try initializeValue(plant: plant, time: timeSeconds, position: positionMeters, rate: rateMetersPerSecond,
            covariance: normalizedCovariance, policy: policy, calls: &calls, phase: &phase, work: &nested) }
        catch { failure = error }
        do { try EstimatorArithmetic.absorb(nested, into: &work, reserved: 512) }
        catch { throw NonlinearEstimatorFailure(cause: error, phase: phase, work: work, derivativeCalls: calls.calls) }
        if let failure { throw NonlinearEstimatorFailure(cause: failure, phase: phase, work: work, derivativeCalls: calls.calls) }
        guard let result else { throw NonlinearEstimatorFailure(cause: .invalidSupplierOutput, phase: phase, work: work, derivativeCalls: calls.calls) }
        do { try EstimatorArithmetic.check(policy) }
        catch { throw NonlinearEstimatorFailure(cause: error, phase: "publication", work: work, derivativeCalls: calls.calls) }
        return result
    }

    @inline(never)
    public func update(_ checkpoint: NonlinearEstimatorCheckpoint, request: NonlinearEstimatorRequest,
                       policy: NonlinearEstimatorPolicy, work: inout NumericalWork) throws(NonlinearEstimatorFailure) -> NonlinearEstimatorResult {
        var phase = "update-admission", calls: DerivativeSupplierWork
        do { calls = try DerivativeSupplierWork(maximumCalls: policy.maximumDerivativeCalls) }
        catch { throw NonlinearEstimatorFailure(cause: .derivatives(error), phase: phase, work: work, derivativeCalls: 0) }
        var nested: NumericalWork
        do {
            try EstimatorArithmetic.charge(256, policy: policy, work: &work)
            try EstimatorArithmetic.reserve(512, policy: policy, work: &work)
            nested = try EstimatorArithmetic.nested(work, reserved: 512, policy: policy)
        } catch { throw NonlinearEstimatorFailure(cause: error, phase: phase, work: work, derivativeCalls: calls.calls) }
        var value: EstimatorUpdateEvidence?, prediction: EstimatorPropagationState?, predictedCovariance: EstimatorMatrix2?
        var encoder: JointEncoderObservation?, failure: NonlinearEstimatorCause?
        do {
            let admitted = try admit(checkpoint, request: request, policy: policy, work: &nested)
            phase = "mechanical-prediction"
            let propagated = try MechanicalEstimatorPropagation.propagate(checkpoint, request: request, policy: policy, calls: &calls, work: &nested)
            prediction = propagated
            phase = "covariance-prediction"
            try EstimatorArithmetic.charge(128, policy: policy, work: &nested)
            let propagatedP = try propagated.transition.multiplying(admitted.p).multiplying(propagated.transition.transposed).adding(admitted.q)
            let p = try EstimatorCovarianceSolve.positiveDefinite(propagatedP, policy: policy, work: &nested)
            predictedCovariance = p
            phase = "encoder-prediction"
            let actual = try checkpoint.plant.sample(time: propagated.time, position: propagated.position, rate: propagated.rate,
                effort: request.heldEffortNewtons, policy: policy, calls: &calls, work: &nested)
            let h = try checkpoint.plant.encoder(time: propagated.time, position: propagated.position, rate: propagated.rate,
                acceleration: actual.acceleration, policy: policy, work: &nested)
            encoder = h
            phase = "innovation-update"
            let posterior = try MechanicalEstimatorInnovation.update(prediction: propagated, covariance: p, predictedEncoder: h,
                checkpoint: checkpoint, request: request, policy: policy, work: &nested)
            if request.measurement != nil {
                phase = "posterior-mechanics"
                _ = try checkpoint.plant.sample(time: propagated.time, position: posterior.position, rate: posterior.rate,
                    effort: request.heldEffortNewtons, policy: policy, calls: &calls, work: &nested)
            }
            try EstimatorArithmetic.check(policy)
            value = posterior
        } catch { failure = error }
        do { try EstimatorArithmetic.absorb(nested, into: &work, reserved: 512) }
        catch { throw NonlinearEstimatorFailure(cause: error, phase: phase, work: work, derivativeCalls: calls.calls) }
        if let failure { throw NonlinearEstimatorFailure(cause: failure, phase: phase, work: work, derivativeCalls: calls.calls) }
        guard let value, let prediction, let predictedCovariance, let encoder else {
            throw NonlinearEstimatorFailure(cause: .invalidSupplierOutput, phase: phase, work: work, derivativeCalls: calls.calls)
        }
        do { try EstimatorArithmetic.check(policy) }
        catch { throw NonlinearEstimatorFailure(cause: error, phase: "publication", work: work, derivativeCalls: calls.calls) }
        let next = NonlinearEstimatorCheckpoint(plant: checkpoint.plant, timeSeconds: request.targetTimeSeconds,
            positionMeters: value.position, rateMetersPerSecond: value.rate, normalizedCovariance: value.covariance.values,
            updateSequence: checkpoint.updateSequence+1, lastObservationSequence: value.lastObservationSequence)
        return NonlinearEstimatorResult(checkpoint: next, predictedPositionMeters: prediction.position, predictedRateMetersPerSecond: prediction.rate,
            normalizedTransition: prediction.transition.values, predictedNormalizedCovariance: predictedCovariance.values,
            predictedEncoder: encoder, normalizedInnovation: value.innovation, normalizedInnovationVariance: value.innovationVariance,
            normalizedInnovationSquared: value.normalizedSquared, normalizedGain: value.gain, work: work, derivativeCalls: calls.calls)
    }

    @inline(never)
    private func initializeValue(plant: PrismaticEstimationModel, time: Double, position: Double, rate: Double, covariance: [Double],
                                 policy: NonlinearEstimatorPolicy, calls: inout DerivativeSupplierWork, phase: inout String,
                                 work: inout NumericalWork) throws(NonlinearEstimatorCause) -> NonlinearEstimatorCheckpoint {
        guard time.isFinite else { throw .invalidInput }
        try plant.validateMetadata(policy: policy, work: &work)
        try plant.domain(position: position, rate: rate, policy: policy)
        phase = "initial-covariance"
        let p = try EstimatorCovarianceSolve.positiveDefinite(EstimatorMatrix2(covariance), policy: policy, work: &work)
        phase = "initial-mechanics"
        let physical = try plant.sample(time: time, position: position, rate: rate, effort: 0, policy: policy, calls: &calls, work: &work)
        phase = "initial-encoder"
        _ = try plant.encoder(time: time, position: position, rate: rate, acceleration: physical.acceleration, policy: policy, work: &work)
        return NonlinearEstimatorCheckpoint(plant: plant, timeSeconds: time, positionMeters: position,
            rateMetersPerSecond: rate, normalizedCovariance: p.values, updateSequence: 0, lastObservationSequence: nil)
    }

    private func admit(_ checkpoint: NonlinearEstimatorCheckpoint, request: NonlinearEstimatorRequest,
                       policy: NonlinearEstimatorPolicy, work: inout NumericalWork) throws(NonlinearEstimatorCause) -> (p: EstimatorMatrix2, q: EstimatorMatrix2) {
        try checkpoint.plant.validateMetadata(policy: policy, work: &work)
        try checkpoint.plant.domain(position: checkpoint.positionMeters, rate: checkpoint.rateMetersPerSecond, policy: policy)
        guard checkpoint.timeSeconds.isFinite, request.targetTimeSeconds.isFinite, request.targetTimeSeconds >= checkpoint.timeSeconds,
              request.heldEffortNewtons.isFinite, abs(request.heldEffortNewtons) <= policy.maximumEffortNewtons else { throw .invalidInput }
        let interval = request.targetTimeSeconds-checkpoint.timeSeconds
        guard interval.isFinite, interval <= policy.maximumIntervalSeconds else { throw .invalidInput }
        guard checkpoint.updateSequence < UInt64.max else { throw .integerOverflow }
        if interval == 0 { guard request.substeps == 0 else { throw .invalidInput } }
        else { guard request.substeps > 0, request.substeps <= policy.maximumSubsteps else { throw .capacityExceeded } }
        if interval == 0 {
            guard request.normalizedProcessCovariance.count == 4,
                  request.normalizedProcessCovariance.allSatisfy({ $0 == 0 }) else { throw .invalidCovariance }
        }
        let q = try EstimatorMatrix2(request.normalizedProcessCovariance).symmetric(policy: policy)
        try q.positiveSemidefinite()
        if interval == 0 { guard q.a == 0, q.b == 0, q.c == 0, q.d == 0 else { throw .invalidCovariance } }
        if let measurement = request.measurement {
            try MechanicalEstimatorInnovation.admit(measurement, plant: checkpoint.plant, target: request.targetTimeSeconds, last: checkpoint.lastObservationSequence)
        }
        let p = try EstimatorCovarianceSolve.positiveDefinite(EstimatorMatrix2(checkpoint.normalizedCovariance), policy: policy, work: &work)
        return (p,q)
    }
}
