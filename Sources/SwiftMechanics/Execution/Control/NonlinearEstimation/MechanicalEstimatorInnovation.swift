internal enum MechanicalEstimatorInnovation {
    @inline(never)
    static func update(prediction: EstimatorPropagationState, covariance p: EstimatorMatrix2, predictedEncoder: JointEncoderObservation,
                       checkpoint: NonlinearEstimatorCheckpoint, request: NonlinearEstimatorRequest, policy: NonlinearEstimatorPolicy,
                       work: inout NumericalWork) throws(NonlinearEstimatorCause) -> EstimatorUpdateEvidence {
        guard let measurement = request.measurement else {
            return EstimatorUpdateEvidence(position: prediction.position, rate: prediction.rate, covariance: p,
                innovation: nil, innovationVariance: nil, normalizedSquared: nil, gain: nil, lastObservationSequence: checkpoint.lastObservationSequence)
        }
        try EstimatorArithmetic.charge(512, policy: policy, work: &work)
        let plant = checkpoint.plant, reading = measurement.encoder
        try admit(measurement, plant: plant, target: request.targetTimeSeconds, last: checkpoint.lastObservationSequence)
        let r = try EstimatorArithmetic.finite(measurement.positionVarianceSquareMeters/(plant.positionScaleMeters*plant.positionScaleMeters))
        guard r > 0 else { throw .invalidCovariance }
        let variance = try EstimatorArithmetic.finite(p.a+r)
        let inverse = try EstimatorCovarianceSolve.inverseInnovation(variance, policy: policy, work: &work)
        let innovation = try EstimatorArithmetic.finite((reading.positions[0]-predictedEncoder.positions[0])/plant.positionScaleMeters)
        let solved = try EstimatorArithmetic.finite(innovation*inverse)
        let originalResidual = try EstimatorArithmetic.finite(variance*solved-innovation)
        let threshold: Double
        do { threshold = try policy.covarianceTolerance.threshold(scale: max(abs(variance*solved),abs(innovation))) }
        catch { throw .numerical(error) }
        guard abs(originalResidual) <= threshold else { throw .invalidSupplierOutput }
        let nis = try EstimatorArithmetic.finite(innovation*solved)
        guard nis >= 0, nis <= policy.maximumNormalizedInnovationSquared else {
            throw .innovationRejected(normalizedSquared: nis, limit: policy.maximumNormalizedInnovationSquared)
        }
        let k0 = try EstimatorArithmetic.finite(p.a*inverse), k1 = try EstimatorArithmetic.finite(p.c*inverse)
        let position = try EstimatorArithmetic.finite(prediction.position+plant.positionScaleMeters*k0*innovation)
        let rate = try EstimatorArithmetic.finite(prediction.rate+plant.rateScaleMetersPerSecond*k1*innovation)
        try plant.domain(position: position, rate: rate, policy: policy)
        let iMinusKH = EstimatorMatrix2(a: 1-k0,b: 0,c: -k1,d: 1)
        let measurementTerm = EstimatorMatrix2(a: k0*r*k0,b: k0*r*k1,c: k1*r*k0,d: k1*r*k1)
        let joseph = try iMinusKH.multiplying(p).multiplying(iMinusKH.transposed).adding(measurementTerm)
        let posterior = try EstimatorCovarianceSolve.positiveDefinite(joseph, policy: policy, work: &work)
        return EstimatorUpdateEvidence(position: position, rate: rate, covariance: posterior, innovation: innovation,
            innovationVariance: variance, normalizedSquared: nis, gain: [k0,k1], lastObservationSequence: measurement.sequence)
    }

    static func admit(_ measurement: NonlinearEstimatorMeasurement, plant: PrismaticEstimationModel,
                      target: Double, last: UInt64?) throws(NonlinearEstimatorCause) {
        let reading = measurement.encoder
        guard reading.model == plant.model.stamp, reading.joint == plant.joint, reading.parentAnchorFrame == plant.parentAnchorFrame,
              reading.positions.count == 1, reading.positions[0].isFinite,
              reading.velocities.count == 1, reading.velocities[0].isFinite,
              reading.coordinateRates.count == 1, reading.coordinateRates[0].isFinite,
              reading.accelerations.count == 1, reading.accelerations[0].isFinite,
              reading.positionUnits == [.length], reading.coordinateRateUnits == [.velocity], reading.velocityUnits == [.velocity],
              reading.accelerationUnits == [.acceleration], reading.accelerationAuthority == .suppliedState,
              reading.velocityConvention == .orderedAxisRates,
              reading.temporalMeaning == .instantaneousContinuous else { throw .sourceMismatch }
        guard reading.timeSeconds.isFinite, measurement.deliveryTimeSeconds.isFinite,
              measurement.positionVarianceSquareMeters.isFinite, measurement.positionVarianceSquareMeters > 0 else { throw .invalidInput }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Delayed-measurement replay is not implemented in this update admission. Production callers reaching an earlier encoder timestamp must fail until bounded timestamp-preserving history, replay and covariance/ordering evidence are implemented; an old reading cannot be treated as current.
        if reading.timeSeconds < target { throw .delayedObservationUnsupported(measured: reading.timeSeconds, target: target) }
        guard reading.timeSeconds == target else { throw .observationTimeMismatch(measured: reading.timeSeconds, target: target) }
        guard measurement.deliveryTimeSeconds == target else { throw .deliveryTimeMismatch }
        if let last { guard measurement.sequence > last else { throw .observationSequenceMismatch } }
    }
}
