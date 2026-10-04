
public struct FixedPlanarContinuationCodec: PlanarContinuationCoding, Sendable {
    public let grid: PlanarGrid
    public let model: ModelStamp
    public let schema: RuntimeContributorSchema
    public let encodedSize: Int
    public let requiredScratchBytes: Int
    public let divergenceTolerance: Double
    private let signature: [UInt8]

    public init(grid: PlanarGrid, model: ModelStamp, contributorID: String, maximumBytes: Int,
                divergenceTolerance: Double) throws(PlanarContinuationError) {
        guard maximumBytes >= 0, divergenceTolerance.isFinite, divergenceTolerance >= 0 else { throw .invalidInput }
        var remaining = grid.limits.maximumMetadataBytes
        // All variable metadata is bounded before any count conversion or signature allocation.
        for text in [grid.id, grid.frame.key, grid.source.source, model.identity, contributorID] {
            guard !text.isEmpty else { throw .invalidInput }
            for _ in text.utf8 { guard remaining > 0 else { throw .capacity }; remaining -= 1 }
        }
        var bytes: [UInt8] = []
        try PlanarWireFormat.append(0x3152414e414c5053, bytes: &bytes, maximum: maximumBytes)
        try PlanarWireFormat.append(1, bytes: &bytes, maximum: maximumBytes)
        for text in [grid.id, grid.frame.key, grid.source.source, model.identity, contributorID] {
            try PlanarWireFormat.append(text, bytes: &bytes, maximum: maximumBytes)
        }
        for value in [grid.revision, grid.source.revision, model.revision, UInt64(grid.nx), UInt64(grid.ny),
                      UInt64(grid.limits.maximumCells), UInt64(grid.limits.maximumMetadataBytes)] {
            try PlanarWireFormat.append(value, bytes: &bytes, maximum: maximumBytes)
        }
        for value in [grid.lengthX, grid.lengthY, grid.depth, grid.density, grid.viscosity,
                      grid.limits.maximumSpeed, grid.limits.maximumPressure, grid.limits.maximumAcceleration,
                      grid.limits.maximumStep, divergenceTolerance] {
            try PlanarWireFormat.append(value.bitPattern, bytes: &bytes, maximum: maximumBytes)
        }
        let words = try PlanarWireFormat.sum(4, PlanarWireFormat.product(3, grid.count))
        let size = try PlanarWireFormat.sum(bytes.count, PlanarWireFormat.product(8, words))
        guard size <= maximumBytes else { throw .capacity }
        // Covers the wire/signature plus simultaneously live old/new field arrays during a trial.
        let scratch = try PlanarWireFormat.sum(size, PlanarWireFormat.sum(bytes.count, PlanarWireFormat.product(48, grid.count)))
        self.grid = grid; self.model = model; self.signature = bytes; self.encodedSize = size
        self.requiredScratchBytes = scratch; self.divergenceTolerance = divergenceTolerance
        do throws(RuntimeFailure) {
            self.schema = try RuntimeContributorSchema(id: contributorID, category: .integrator, version: 1, maximumBytes: size)
        } catch { throw .runtime(error.code) }
    }

    @inline(never)
    public func encode(_ state: PlanarState, work: inout PlanarContinuationWork) throws(PlanarContinuationError) -> RuntimeContributorState {
        try work.reserve(requiredScratchBytes)
        var remaining = grid.limits.maximumMetadataBytes
        try work.metadata(state.grid.id, remaining: &remaining)
        try work.metadata(state.grid.frame.key, remaining: &remaining)
        try work.metadata(state.grid.source.source, remaining: &remaining)
        try work.charge(32)
        guard state.grid == grid,
              state.grid.id.utf8.elementsEqual(grid.id.utf8),
              state.grid.frame.key.utf8.elementsEqual(grid.frame.key.utf8),
              state.grid.source.source.utf8.elementsEqual(grid.source.source.utf8) else { throw .staleBinding }
        try reserveValidation(work: &work)
        try validate(state, work: &work)
        try work.charge(encodedSize)
        var bytes = [UInt8](repeating: 0, count: encodedSize)
        for i in signature.indices { bytes[i] = signature[i] }
        var cursor = signature.count
        PlanarWireFormat.put(state.time.bitPattern, bytes: &bytes, cursor: &cursor)
        PlanarWireFormat.put(state.sequence, bytes: &bytes, cursor: &cursor)
        PlanarWireFormat.put(state.source.accelerationX.bitPattern, bytes: &bytes, cursor: &cursor)
        PlanarWireFormat.put(state.source.accelerationY.bitPattern, bytes: &bytes, cursor: &cursor)
        for k in 0..<grid.count { try work.poll(); PlanarWireFormat.put(state.u[k].bitPattern, bytes: &bytes, cursor: &cursor) }
        for k in 0..<grid.count { try work.poll(); PlanarWireFormat.put(state.v[k].bitPattern, bytes: &bytes, cursor: &cursor) }
        for k in 0..<grid.count { try work.poll(); PlanarWireFormat.put(state.pressure[k].bitPattern, bytes: &bytes, cursor: &cursor) }
        try work.poll()
        do throws(RuntimeFailure) {
            return try RuntimeContributorState(id: schema.id, category: schema.category, version: schema.version, bytes: bytes)
        } catch { throw .runtime(error.code) }
    }

    @inline(never)
    public func decode(_ record: RuntimeContributorState, work: inout PlanarContinuationWork) throws(PlanarContinuationError) -> PlanarState {
        try work.reserve(requiredScratchBytes)
        var remaining = grid.limits.maximumMetadataBytes
        try work.metadata(record.id, remaining: &remaining)
        guard record.id.utf8.elementsEqual(schema.id.utf8), record.category == schema.category,
              record.version == schema.version else { throw .staleBinding }
        guard record.bytes.count <= encodedSize else { throw .capacity }
        guard record.bytes.count == encodedSize else { throw .malformedPayload }
        try work.charge(encodedSize)
        for i in signature.indices {
            try work.poll()
            guard record.bytes[i] == signature[i] else { throw .staleBinding }
        }
        try reserveValidation(work: &work)
        var cursor = signature.count
        let time = Double(bitPattern: PlanarWireFormat.read(record.bytes, cursor: &cursor))
        let sequence = PlanarWireFormat.read(record.bytes, cursor: &cursor)
        let ax = Double(bitPattern: PlanarWireFormat.read(record.bytes, cursor: &cursor))
        let ay = Double(bitPattern: PlanarWireFormat.read(record.bytes, cursor: &cursor))
        var u = [Double](repeating: 0, count: grid.count)
        var v = [Double](repeating: 0, count: grid.count)
        var p = [Double](repeating: 0, count: grid.count)
        for k in 0..<grid.count { try work.poll(); u[k] = Double(bitPattern: PlanarWireFormat.read(record.bytes, cursor: &cursor)) }
        for k in 0..<grid.count { try work.poll(); v[k] = Double(bitPattern: PlanarWireFormat.read(record.bytes, cursor: &cursor)) }
        for k in 0..<grid.count { try work.poll(); p[k] = Double(bitPattern: PlanarWireFormat.read(record.bytes, cursor: &cursor)) }
        let state: PlanarState
        do throws(PlanarFluidError) {
            let source = try PlanarSource(accelerationX: ax, accelerationY: ay)
            state = try PlanarState(grid: grid, time: time, sequence: sequence, u: u, v: v, pressure: p, source: source)
        } catch { throw .physical(error) }
        try validate(state, work: &work)
        try work.poll(); return state
    }

    private func validate(_ state: PlanarState, work: inout PlanarContinuationWork) throws(PlanarContinuationError) {
        guard state.u.count == grid.count, state.v.count == grid.count, state.pressure.count == grid.count else { throw .staleBinding }
        guard state.time.isFinite, state.time >= 0, state.pressure[0] == 0,
              state.source.accelerationX.isFinite, state.source.accelerationY.isFinite,
              abs(state.source.accelerationX) <= grid.limits.maximumAcceleration,
              abs(state.source.accelerationY) <= grid.limits.maximumAcceleration else { throw .physical(.invalidInput) }
        for k in 0..<grid.count {
            try work.poll()
            guard state.u[k].isFinite, state.v[k].isFinite, state.pressure[k].isFinite else { throw .physical(.nonfinite) }
            guard abs(state.u[k]) <= grid.limits.maximumSpeed, abs(state.v[k]) <= grid.limits.maximumSpeed,
                  abs(state.pressure[k]) <= grid.limits.maximumPressure else { throw .physical(.domain) }
            let i = k % grid.nx, j = k / grid.nx
            let right = j*grid.nx+(i+1)%grid.nx, top = ((j+1)%grid.ny)*grid.nx+i
            let divergence = (state.u[right]-state.u[k])/grid.dx+(state.v[top]-state.v[k])/grid.dy
            guard divergence.isFinite, abs(divergence) <= divergenceTolerance else { throw .physical(.originalResidual) }
        }
        try work.poll()
    }
    private func reserveValidation(work: inout PlanarContinuationWork) throws(PlanarContinuationError) {
        try work.charge(PlanarWireFormat.sum(16, PlanarWireFormat.product(64, grid.count)))
    }
}
