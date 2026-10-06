public struct ReferenceLinearEstimator: LinearEstimating, Sendable {
    public init() {}
    public func admit(source: ModelStamp, filterIdentity: String, filterRevision: UInt64, chartIdentity: String,
                      clock: LinearEstimatorClock, stateCoordinates: [LinearEstimatorCoordinate],
                      inputCoordinates: [LinearEstimatorCoordinate], observationCoordinates: [LinearEstimatorCoordinate],
                      transition: DenseMatrix<Double>, input: DenseMatrix<Double>, observation: DenseMatrix<Double>,
                      processCovariance: DenseMatrix<Double>, observationCovariance: DenseMatrix<Double>,
                      policy: LinearEstimatorPolicy, work: inout NumericalWork) throws(LinearEstimatorFailure) -> LinearEstimatorModel {
        do throws(LinearEstimatorError) {
            let model = LinearEstimatorModel(source: source, filterIdentity: filterIdentity, filterRevision: filterRevision,
                chartIdentity: chartIdentity, clock: clock, stateCoordinates: stateCoordinates, inputCoordinates: inputCoordinates,
                observationCoordinates: observationCoordinates, transition: transition, input: input, observation: observation,
                processCovariance: processCovariance, observationCovariance: observationCovariance)
            let n = stateCoordinates.count, m = observationCoordinates.count, r = inputCoordinates.count
            guard filterRevision > 0, clock.epochSeconds.isFinite, clock.periodSeconds.isFinite, clock.periodSeconds > 0,
                  clock.maximumTick > 0, transition.rowCount == n, transition.columnCount == n,
                  input.rowCount == n, input.columnCount == r, observation.rowCount == m, observation.columnCount == n,
                  processCovariance.rowCount == n, processCovariance.columnCount == n,
                  observationCovariance.rowCount == m, observationCovariance.columnCount == m else { throw .invalidModel }
            _ = try LinearEstimatorAlgebra.reserve(model, policy: policy, work: &work)
            let end = try LinearEstimatorAlgebra.time(clock, tick: clock.maximumTick)
            guard end > clock.epochSeconds else { throw .timingMismatch }
            try LinearEstimatorAlgebra.covariance(processCovariance, positive: false, policy: policy, work: &work)
            try LinearEstimatorAlgebra.covariance(observationCovariance, positive: true, policy: policy, work: &work)
            try LinearEstimatorAlgebra.observable(model, policy: policy, work: &work)
            try LinearEstimatorAlgebra.check(policy)
            return model
        } catch { throw LinearEstimatorFailure(cause: error, prefix: nil, admittedWork: work) }
    }
    public func initialize(model: LinearEstimatorModel, mean: [Double], covariance: DenseMatrix<Double>,
                           policy: LinearEstimatorPolicy, work: inout NumericalWork) throws(LinearEstimatorFailure) -> LinearEstimatorState {
        do throws(LinearEstimatorError) {
            _ = try LinearEstimatorAlgebra.reserve(model, policy: policy, work: &work)
            try validateMean(mean, count: model.stateCoordinates.count, policy: policy, work: &work)
            guard covariance.rowCount == mean.count, covariance.columnCount == mean.count else { throw .invalidState }
            try LinearEstimatorAlgebra.covariance(covariance, positive: false, policy: policy, work: &work)
            try LinearEstimatorAlgebra.check(policy)
            return LinearEstimatorState(model: model, tick: 0, timeSeconds: model.clock.epochSeconds, mean: mean,
                covariance: covariance, sampleResolved: true, lastObservationSequence: nil, lastObservationTimeSeconds: nil)
        } catch { throw LinearEstimatorFailure(cause: error, prefix: nil, admittedWork: work) }
    }
    public func predict(_ prefix: LinearEstimatorState, input: LinearEstimatorInput, policy: LinearEstimatorPolicy,
                        work: inout NumericalWork) throws(LinearEstimatorFailure) -> LinearEstimatorState {
        do throws(LinearEstimatorError) {
            _ = try validate(prefix, policy: policy, work: &work)
            guard prefix.sampleResolved else { throw .unresolvedSample }
            let model = prefix.model, next = prefix.tick.addingReportingOverflow(1)
            guard !next.overflow else { throw .timingMismatch }
            let end = try LinearEstimatorAlgebra.time(model.clock, tick: next.partialValue)
            guard end > prefix.timeSeconds, input.intervalStartSeconds == prefix.timeSeconds,
                  input.intervalEndSeconds == end else { throw .timingMismatch }
            try association(source: input.source, identity: input.filterIdentity, revision: input.filterRevision,
                coordinates: input.coordinates, expected: model.inputCoordinates, model: model, policy: policy, work: &work)
            try validateMean(input.normalizedValues, count: model.inputCoordinates.count, policy: policy, work: &work)
            let x = try LinearEstimatorAlgebra.matrix(prefix.mean, rows: prefix.mean.count, columns: 1)
            let u = try LinearEstimatorAlgebra.matrix(input.normalizedValues, rows: input.normalizedValues.count, columns: 1)
            let ax = try LinearEstimatorAlgebra.multiply(model.transition, x, policy: policy, work: &work)
            let bu = try LinearEstimatorAlgebra.multiply(model.input, u, policy: policy, work: &work)
            let mean = try LinearEstimatorAlgebra.add(ax, bu, policy: policy, work: &work).storage
            let ap = try LinearEstimatorAlgebra.multiply(model.transition, prefix.covariance, policy: policy, work: &work)
            let at = try LinearEstimatorAlgebra.transpose(model.transition, policy: policy, work: &work)
            let apat = try LinearEstimatorAlgebra.multiply(ap, at, policy: policy, work: &work)
            try LinearEstimatorAlgebra.covariance(model.processCovariance, positive: false, policy: policy, work: &work)
            let candidate = try LinearEstimatorAlgebra.add(apat, model.processCovariance, policy: policy, work: &work)
            let covariance = try LinearEstimatorAlgebra.symmetric(candidate, allowRoundoff: true, policy: policy, work: &work)
            try LinearEstimatorAlgebra.covariance(covariance, positive: false, policy: policy, work: &work)
            try LinearEstimatorAlgebra.check(policy)
            return LinearEstimatorState(model: model, tick: next.partialValue, timeSeconds: end, mean: mean,
                covariance: covariance, sampleResolved: false, lastObservationSequence: prefix.lastObservationSequence,
                lastObservationTimeSeconds: prefix.lastObservationTimeSeconds)
        } catch { throw LinearEstimatorFailure(cause: error, prefix: prefix, admittedWork: work) }
    }
    public func update(_ prefix: LinearEstimatorState, observation: LinearEstimatorObservation?, missing: LinearEstimatorMissingPolicy,
                       policy: LinearEstimatorPolicy, work: inout NumericalWork) throws(LinearEstimatorFailure) -> LinearEstimatorUpdate {
        do throws(LinearEstimatorError) {
            let reserved = try validate(prefix, policy: policy, work: &work)
            guard !prefix.sampleResolved else { throw .unresolvedSample }
            guard let observation else {
                switch missing {
                case .fail: throw .missingObservation
                case .retainPrediction:
                    try LinearEstimatorAlgebra.check(policy)
                    let state = LinearEstimatorState(model: prefix.model, tick: prefix.tick, timeSeconds: prefix.timeSeconds,
                        mean: prefix.mean, covariance: prefix.covariance, sampleResolved: true,
                        lastObservationSequence: prefix.lastObservationSequence, lastObservationTimeSeconds: prefix.lastObservationTimeSeconds)
                    return LinearEstimatorUpdate(state: state, innovation: nil, gain: nil, innovationCovariance: nil,
                        supplierSolveDiagnostics: [], missingObservation: true)
                }
            }
            let model = prefix.model, n = model.stateCoordinates.count, m = model.observationCoordinates.count
            try association(source: observation.source, identity: observation.filterIdentity, revision: observation.filterRevision,
                coordinates: observation.coordinates, expected: model.observationCoordinates, model: model, policy: policy, work: &work)
            guard observation.sampleTimeSeconds.isFinite, observation.deliveryTimeSeconds.isFinite else { throw .timingMismatch }
            guard observation.sampleTimeSeconds >= prefix.timeSeconds,
                  observation.deliveryTimeSeconds <= observation.sampleTimeSeconds else { throw .delayedObservation }
            guard observation.sampleTimeSeconds == prefix.timeSeconds, observation.deliveryTimeSeconds == prefix.timeSeconds else { throw .timingMismatch }
            if let sequence = prefix.lastObservationSequence { guard observation.sequence > sequence else { throw .outOfOrderObservation } }
            if let time = prefix.lastObservationTimeSeconds { guard observation.sampleTimeSeconds > time else { throw .outOfOrderObservation } }
            try validateMean(observation.normalizedValues, count: m, policy: policy, work: &work)
            let x = try LinearEstimatorAlgebra.matrix(prefix.mean, rows: n, columns: 1)
            let hx = try LinearEstimatorAlgebra.multiply(model.observation, x, policy: policy, work: &work)
            var innovation = observation.normalizedValues
            for i in innovation.indices { try LinearEstimatorAlgebra.charge(1, policy: policy, work: &work); innovation[i] = try LinearEstimatorAlgebra.finite(innovation[i]-hx.storage[i]) }
            let ht = try LinearEstimatorAlgebra.transpose(model.observation, policy: policy, work: &work)
            let pht = try LinearEstimatorAlgebra.multiply(prefix.covariance, ht, policy: policy, work: &work)
            let hpht = try LinearEstimatorAlgebra.multiply(model.observation, pht, policy: policy, work: &work)
            try LinearEstimatorAlgebra.covariance(model.observationCovariance, positive: true, policy: policy, work: &work)
            let rawS = try LinearEstimatorAlgebra.add(hpht, model.observationCovariance, policy: policy, work: &work)
            let s = try LinearEstimatorAlgebra.symmetric(rawS, allowRoundoff: true, policy: policy, work: &work)
            try LinearEstimatorAlgebra.covariance(s, positive: true, policy: policy, work: &work)
            var gainValues = [Double](repeating: 0, count: try LinearEstimatorAlgebra.product(n, m))
            var diagnostics: [LinearDiagnostics<Double>] = []; diagnostics.reserveCapacity(n)
            var rhs = [Double](repeating: 0, count: m)
            for i in 0..<n {
                for j in 0..<m { try LinearEstimatorAlgebra.charge(1, policy: policy, work: &work); rhs[j] = pht.storage[i*m+j] }
                let solution = try LinearEstimatorAlgebra.solve(s, rhs: rhs, reserved: reserved, policy: policy, work: &work)
                diagnostics.append(solution.diagnostics)
                for j in 0..<m { try LinearEstimatorAlgebra.charge(1, policy: policy, work: &work); gainValues[i*m+j] = solution.values[j] }
            }
            let gain = try LinearEstimatorAlgebra.matrix(gainValues, rows: n, columns: m)
            let residual = try LinearEstimatorAlgebra.matrix(innovation, rows: m, columns: 1)
            let correction = try LinearEstimatorAlgebra.multiply(gain, residual, policy: policy, work: &work)
            let mean = try LinearEstimatorAlgebra.add(x, correction, policy: policy, work: &work).storage
            let kh = try LinearEstimatorAlgebra.multiply(gain, model.observation, policy: policy, work: &work)
            var identityMinus = kh.storage
            for i in 0..<n { for j in 0..<n {
                try LinearEstimatorAlgebra.charge(1, policy: policy, work: &work)
                identityMinus[i*n+j] = try LinearEstimatorAlgebra.finite((i == j ? 1.0 : 0.0)-identityMinus[i*n+j])
            } }
            let c = try LinearEstimatorAlgebra.matrix(identityMinus, rows: n, columns: n)
            let cp = try LinearEstimatorAlgebra.multiply(c, prefix.covariance, policy: policy, work: &work)
            let ct = try LinearEstimatorAlgebra.transpose(c, policy: policy, work: &work)
            let cpct = try LinearEstimatorAlgebra.multiply(cp, ct, policy: policy, work: &work)
            let kr = try LinearEstimatorAlgebra.multiply(gain, model.observationCovariance, policy: policy, work: &work)
            let kt = try LinearEstimatorAlgebra.transpose(gain, policy: policy, work: &work)
            let krkt = try LinearEstimatorAlgebra.multiply(kr, kt, policy: policy, work: &work)
            let rawP = try LinearEstimatorAlgebra.add(cpct, krkt, policy: policy, work: &work)
            let covariance = try LinearEstimatorAlgebra.symmetric(rawP, allowRoundoff: true, policy: policy, work: &work)
            try LinearEstimatorAlgebra.covariance(covariance, positive: false, policy: policy, work: &work)
            try LinearEstimatorAlgebra.check(policy)
            let state = LinearEstimatorState(model: model, tick: prefix.tick, timeSeconds: prefix.timeSeconds, mean: mean,
                covariance: covariance, sampleResolved: true, lastObservationSequence: observation.sequence,
                lastObservationTimeSeconds: observation.sampleTimeSeconds)
            return LinearEstimatorUpdate(state: state, innovation: innovation, gain: gain, innovationCovariance: s,
                supplierSolveDiagnostics: diagnostics, missingObservation: false)
        } catch { throw LinearEstimatorFailure(cause: error, prefix: prefix, admittedWork: work) }
    }
    private func validateMean(_ values: [Double], count: Int, policy: LinearEstimatorPolicy,
                              work: inout NumericalWork) throws(LinearEstimatorError) {
        guard values.count == count else { throw .invalidInput }
        for value in values { try LinearEstimatorAlgebra.charge(1, policy: policy, work: &work); guard value.isFinite else { throw .invalidInput } }
    }
    internal func validate(_ state: LinearEstimatorState, policy: LinearEstimatorPolicy,
                           work: inout NumericalWork) throws(LinearEstimatorError) -> Int {
        let reserved = try LinearEstimatorAlgebra.reserve(state.model, policy: policy, work: &work)
        guard state.timeSeconds == (try LinearEstimatorAlgebra.time(state.model.clock, tick: state.tick)),
              state.covariance.rowCount == state.model.stateCoordinates.count,
              state.covariance.columnCount == state.model.stateCoordinates.count,
              (state.lastObservationSequence == nil) == (state.lastObservationTimeSeconds == nil) else { throw .invalidState }
        if state.tick == 0 {
            guard state.sampleResolved, state.lastObservationSequence == nil else { throw .invalidState }
        }
        if let time = state.lastObservationTimeSeconds {
            guard time.isFinite, time >= state.model.clock.epochSeconds, time <= state.timeSeconds else { throw .invalidState }
            let ratio = (time-state.model.clock.epochSeconds)/state.model.clock.periodSeconds
            guard ratio.isFinite, let observedTick = UInt64(exactly: ratio.rounded()), observedTick > 0,
                  observedTick <= state.tick,
                  time == (try LinearEstimatorAlgebra.time(state.model.clock, tick: observedTick)) else { throw .invalidState }
            if !state.sampleResolved { guard time < state.timeSeconds else { throw .invalidState } }
        }
        try validateMean(state.mean, count: state.model.stateCoordinates.count, policy: policy, work: &work)
        try LinearEstimatorAlgebra.covariance(state.covariance, positive: false, policy: policy, work: &work)
        return reserved
    }
    private func association(source: ModelStamp, identity: String, revision: UInt64, coordinates: [LinearEstimatorCoordinate],
                             expected: [LinearEstimatorCoordinate], model: LinearEstimatorModel, policy: LinearEstimatorPolicy,
                             work: inout NumericalWork) throws(LinearEstimatorError) {
        try LinearEstimatorAlgebra.metadata(source.identity, policy: policy, work: &work)
        try LinearEstimatorAlgebra.metadata(identity, policy: policy, work: &work)
        guard coordinates.count == expected.count else { throw .sourceMismatch }
        try LinearEstimatorAlgebra.coordinates(coordinates, policy: policy, work: &work)
        try LinearEstimatorAlgebra.charge(try LinearEstimatorAlgebra.product(4, coordinates.count), policy: policy, work: &work)
        guard source == model.source, identity == model.filterIdentity, revision == model.filterRevision,
              coordinates == expected else { throw .sourceMismatch }
    }
}
