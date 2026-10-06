public struct ReferenceLinearEstimatorContinuationCodec: LinearEstimatorContinuationCoding, Sendable {
    public init() {}
    public func schema(model: LinearEstimatorModel, policy: LinearEstimatorPolicy,
                       work: inout NumericalWork) throws(LinearEstimatorFailure) -> RuntimeContributorSchema {
        do throws(LinearEstimatorError) {
            let bytes = try prefix(model, policy: policy, work: &work)
            return try makeSchema(model, size: try total(model, prefixCount: bytes.count, policy: policy), policy: policy, work: &work)
        } catch { throw LinearEstimatorFailure(cause: error, prefix: nil, admittedWork: work) }
    }
    public func record(_ state: LinearEstimatorState, policy: LinearEstimatorPolicy,
                       work: inout NumericalWork) throws(LinearEstimatorFailure) -> RuntimeContributorState {
        do throws(LinearEstimatorError) {
            let reserved = try ReferenceLinearEstimator().validate(state, policy: policy, work: &work)
            var bytes = try prefix(state.model, policy: policy, work: &work)
            let size = try total(state.model, prefixCount: bytes.count, policy: policy)
            try LinearEstimatorAlgebra.storage(try LinearEstimatorAlgebra.sum(reserved, size), work: &work)
            let schema = try makeSchema(state.model, size: size, policy: policy, work: &work)
            bytes.reserveCapacity(size)
            for word in [state.tick, state.timeSeconds.bitPattern, state.sampleResolved ? 1 : 0,
                         state.lastObservationSequence == nil ? 0 : 1, state.lastObservationSequence ?? 0,
                         (state.lastObservationTimeSeconds ?? 0).bitPattern] {
                try put(word, into: &bytes, policy: policy, work: &work)
            }
            for value in state.mean { try put(value.bitPattern, into: &bytes, policy: policy, work: &work) }
            for value in state.covariance.storage { try put(value.bitPattern, into: &bytes, policy: policy, work: &work) }
            guard bytes.count == size else { throw .corruptContinuation }
            try LinearEstimatorAlgebra.check(policy)
            do { return try RuntimeContributorState(id: schema.id, category: schema.category, version: schema.version, bytes: bytes) }
            catch { throw .corruptContinuation }
        } catch { throw LinearEstimatorFailure(cause: error, prefix: state, admittedWork: work) }
    }
    public func restore(_ record: RuntimeContributorState, model: LinearEstimatorModel, policy: LinearEstimatorPolicy,
                        work: inout NumericalWork) throws(LinearEstimatorFailure) -> LinearEstimatorState {
        do throws(LinearEstimatorError) {
            let expected = try prefix(model, policy: policy, work: &work)
            let size = try total(model, prefixCount: expected.count, policy: policy)
            let schema = try makeSchema(model, size: size, policy: policy, work: &work)
            guard record.bytes.count == size, record.id.utf8.count <= policy.maximumMetadataBytes else { throw .corruptContinuation }
            try LinearEstimatorAlgebra.metadata(record.id, policy: policy, work: &work)
            guard record.id == schema.id, record.version == 1, record.category == .controller else { throw .corruptContinuation }
            try LinearEstimatorAlgebra.charge(expected.count, policy: policy, work: &work)
            guard record.bytes.starts(with: expected) else { throw .corruptContinuation }
            let reserved = try LinearEstimatorAlgebra.reserve(model, policy: policy, work: &work)
            try LinearEstimatorAlgebra.storage(try LinearEstimatorAlgebra.sum(reserved, try LinearEstimatorAlgebra.product(3, size)), work: &work)
            var index = expected.count
            let tick = try get(record.bytes, index: &index, policy: policy, work: &work)
            let time = Double(bitPattern: try get(record.bytes, index: &index, policy: policy, work: &work))
            let resolved = try get(record.bytes, index: &index, policy: policy, work: &work)
            let hasObservation = try get(record.bytes, index: &index, policy: policy, work: &work)
            let sequence = try get(record.bytes, index: &index, policy: policy, work: &work)
            let lastTimeBits = try get(record.bytes, index: &index, policy: policy, work: &work)
            guard resolved <= 1, hasObservation <= 1,
                  hasObservation == 1 || (sequence == 0 && lastTimeBits == 0) else { throw .corruptContinuation }
            let n = model.stateCoordinates.count
            var mean: [Double] = []; mean.reserveCapacity(n)
            for _ in 0..<n { mean.append(Double(bitPattern: try get(record.bytes, index: &index, policy: policy, work: &work))) }
            var covariance: [Double] = []; covariance.reserveCapacity(try LinearEstimatorAlgebra.product(n, n))
            for _ in 0..<(try LinearEstimatorAlgebra.product(n, n)) {
                covariance.append(Double(bitPattern: try get(record.bytes, index: &index, policy: policy, work: &work)))
            }
            guard index == record.bytes.count else { throw .corruptContinuation }
            let state = LinearEstimatorState(model: model, tick: tick, timeSeconds: time, mean: mean,
                covariance: try LinearEstimatorAlgebra.matrix(covariance, rows: n, columns: n), sampleResolved: resolved == 1,
                lastObservationSequence: hasObservation == 1 ? sequence : nil,
                lastObservationTimeSeconds: hasObservation == 1 ? Double(bitPattern: lastTimeBits) : nil)
            _ = try ReferenceLinearEstimator().validate(state, policy: policy, work: &work)
            try LinearEstimatorAlgebra.check(policy)
            return state
        } catch { throw LinearEstimatorFailure(cause: error, prefix: nil, admittedWork: work) }
    }
    private func makeSchema(_ model: LinearEstimatorModel, size: Int, policy: LinearEstimatorPolicy,
                            work: inout NumericalWork) throws(LinearEstimatorError) -> RuntimeContributorSchema {
        let count = try LinearEstimatorAlgebra.sum("mechanics.linearEstimator.".utf8.count, model.filterIdentity.utf8.count)
        guard count <= policy.maximumMetadataBytes else { throw .capacity }
        try LinearEstimatorAlgebra.charge(count, policy: policy, work: &work)
        do { return try RuntimeContributorSchema(id: "mechanics.linearEstimator."+model.filterIdentity,
                    category: .controller, version: 1, maximumBytes: size) }
        catch { throw .corruptContinuation }
    }
    private func total(_ model: LinearEstimatorModel, prefixCount: Int,
                       policy: LinearEstimatorPolicy) throws(LinearEstimatorError) -> Int {
        let n = model.stateCoordinates.count
        let scalars = try LinearEstimatorAlgebra.sum(n, try LinearEstimatorAlgebra.product(n, n))
        let size = try LinearEstimatorAlgebra.sum(prefixCount, try LinearEstimatorAlgebra.product(8, try LinearEstimatorAlgebra.sum(6, scalars)))
        guard size <= policy.maximumContinuationBytes else { throw .capacity }
        return size
    }
    private func prefix(_ model: LinearEstimatorModel, policy: LinearEstimatorPolicy,
                        work: inout NumericalWork) throws(LinearEstimatorError) -> [UInt8] {
        let reserved = try LinearEstimatorAlgebra.reserve(model, policy: policy, work: &work)
        var size = 8*20
        for text in [model.source.identity, model.filterIdentity, model.chartIdentity] {
            size = try LinearEstimatorAlgebra.sum(size, try LinearEstimatorAlgebra.sum(8, text.utf8.count))
        }
        for coordinates in [model.stateCoordinates, model.inputCoordinates, model.observationCoordinates] {
            for coordinate in coordinates {
                size = try LinearEstimatorAlgebra.sum(size, try LinearEstimatorAlgebra.sum(32,
                    try LinearEstimatorAlgebra.sum(coordinate.identity.utf8.count, coordinate.frame.utf8.count)))
            }
        }
        for matrix in [model.transition, model.input, model.observation, model.processCovariance, model.observationCovariance] {
            size = try LinearEstimatorAlgebra.sum(size, try LinearEstimatorAlgebra.product(8, matrix.storage.count))
        }
        _ = try total(model, prefixCount: size, policy: policy)
        try LinearEstimatorAlgebra.storage(try LinearEstimatorAlgebra.sum(reserved, size), work: &work)
        var bytes: [UInt8] = []; bytes.reserveCapacity(size)
        for word in [UInt64(1), model.source.revision, model.filterRevision, model.clock.epochSeconds.bitPattern,
                     model.clock.periodSeconds.bitPattern, model.clock.maximumTick, UInt64(model.stateCoordinates.count),
                     UInt64(model.inputCoordinates.count), UInt64(model.observationCoordinates.count),
                     UInt64(policy.maximumStateCount), UInt64(policy.maximumInputCount), UInt64(policy.maximumObservationCount),
                     UInt64(policy.maximumMetadataBytes), UInt64(policy.maximumContinuationBytes), policy.maximumCoefficientMagnitude.bitPattern,
                     policy.covarianceTolerance.bitPattern, policy.rankThreshold.bitPattern,
                     policy.solveTolerance.absoluteResidual.bitPattern, policy.solveTolerance.relativeResidual.bitPattern,
                     policy.solveTolerance.pivotThreshold.bitPattern] {
            try put(word, into: &bytes, policy: policy, work: &work)
        }
        for text in [model.source.identity, model.filterIdentity, model.chartIdentity] { try putText(text, into: &bytes, policy: policy, work: &work) }
        for coordinates in [model.stateCoordinates, model.inputCoordinates, model.observationCoordinates] {
            for coordinate in coordinates {
                try putText(coordinate.identity, into: &bytes, policy: policy, work: &work)
                try putText(coordinate.frame, into: &bytes, policy: policy, work: &work)
                let dimension = coordinate.dimension
                for exponent in [dimension.length, dimension.mass, dimension.time, dimension.angle, dimension.electricCurrent,
                                 dimension.temperature, dimension.amount, dimension.luminousIntensity] {
                    try LinearEstimatorAlgebra.charge(1, policy: policy, work: &work); bytes.append(UInt8(bitPattern: exponent))
                }
                try put(coordinate.normalizationSI.bitPattern, into: &bytes, policy: policy, work: &work)
            }
        }
        for matrix in [model.transition, model.input, model.observation, model.processCovariance, model.observationCovariance] {
            for value in matrix.storage { try put(value.bitPattern, into: &bytes, policy: policy, work: &work) }
        }
        guard bytes.count == size else { throw .corruptContinuation }
        return bytes
    }
    private func putText(_ text: String, into bytes: inout [UInt8], policy: LinearEstimatorPolicy,
                         work: inout NumericalWork) throws(LinearEstimatorError) {
        try put(UInt64(text.utf8.count), into: &bytes, policy: policy, work: &work)
        for byte in text.utf8 { try LinearEstimatorAlgebra.charge(1, policy: policy, work: &work); bytes.append(byte) }
    }
    private func put(_ word: UInt64, into bytes: inout [UInt8], policy: LinearEstimatorPolicy,
                     work: inout NumericalWork) throws(LinearEstimatorError) {
        for shift in stride(from: 0, to: 64, by: 8) {
            try LinearEstimatorAlgebra.charge(1, policy: policy, work: &work); bytes.append(UInt8(truncatingIfNeeded: word >> shift))
        }
    }
    private func get(_ bytes: [UInt8], index: inout Int, policy: LinearEstimatorPolicy,
                     work: inout NumericalWork) throws(LinearEstimatorError) -> UInt64 {
        guard index >= 0, index <= bytes.count, bytes.count-index >= 8 else { throw .corruptContinuation }
        var word: UInt64 = 0
        for shift in stride(from: 0, to: 64, by: 8) {
            try LinearEstimatorAlgebra.charge(1, policy: policy, work: &work); word |= UInt64(bytes[index]) << shift; index += 1
        }
        return word
    }
}
