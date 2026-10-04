import SwiftMechanics

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    static func verifyPlanarRuntime() throws {
        let context = try PlanarRuntimeProbeContext()
        defer { _ = context.session.shutdown() }
        try verifyPlanarAcceptance(context)
        try verifyPlanarReplay(context)
        try verifyPlanarFailures(context)
        print("Planar Runtime verification passed: real MAC pressure, reject/RNG, exact restart and failed prefix.")
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyPlanarAcceptance(_ context: PlanarRuntimeProbeContext) throws {
        let prefix = context.session.snapshot()
        let rejected = try context.advance(decision: .reject)
        try require(rejected.accepted == prefix && context.session.snapshot() == prefix)
        _ = try context.advance()
        let state = try context.accepted(), accepted = context.session.snapshot()
        try require(state.time == 0.01 && state.sequence == 1 && accepted.checkpoint.random.draws == 1)
        try require(state.pressure.contains { abs($0) > 1e-6 } && state.u != context.initial.u)
        var oldEnergy = 0.0, newEnergy = 0.0
        for k in 0..<state.grid.count {
            try require(abs(PlanarProbeContext.divergence(state, at: k)) < 1e-9)
            oldEnergy += 0.5*state.grid.cellMass*(context.initial.u[k]*context.initial.u[k]+context.initial.v[k]*context.initial.v[k])
            newEnergy += 0.5*state.grid.cellMass*(state.u[k]*state.u[k]+state.v[k]*state.v[k])
        }
        try require(newEnergy < oldEnergy)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyPlanarReplay(_ context: PlanarRuntimeProbeContext) throws {
        let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        let prefix = context.session.snapshot()
        let wire = try context.session.checkpoint(codec: codec)
        let uninterrupted = try context.advance().accepted
        let field = try context.accepted()
        _ = try context.session.restart(wire, codec: codec)
        try require(context.session.snapshot() == prefix)
        try require(try context.advance().accepted == uninterrupted && context.accepted() == field)
        try verifyPlanarFreshOwner(wire, expected: uninterrupted, field: field)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyPlanarFreshOwner(_ wire: [UInt8], expected: RuntimeAcceptedState, field: PlanarState) throws {
        let fresh = try PlanarRuntimeProbeContext()
        defer { _ = fresh.session.shutdown() }
        _ = try fresh.session.restart(wire, codec: NativeRuntimeCheckpointCodec())
        try require(try fresh.advance().accepted == expected && fresh.accepted() == field)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyPlanarFailures(_ context: PlanarRuntimeProbeContext) throws {
        let prefix = context.session.snapshot()
        var refused = false
        do throws(RuntimeFailure) { _ = try context.advance(iterations: 0) }
        catch {
            try require(error.failedSupplierWorkUnavailable && error.lastAccepted == prefix)
            refused = true
        }
        try require(refused && context.session.snapshot() == prefix)
        try verifyPlanarForgedTime(context)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func verifyPlanarForgedTime(_ context: PlanarRuntimeProbeContext) throws {
        let prefix = context.session.snapshot(), checkpoint = prefix.checkpoint
        let old = checkpoint.contributors[0]
        var field = old.bytes
        let offset = context.codec.encodedSize-8*(4+3*context.initial.grid.count)
        for i in 0..<8 { field[offset+i] = UInt8(truncatingIfNeeded: Double(2).bitPattern >> (8*i)) }
        let record = try RuntimeContributorState(id: old.id, category: old.category, version: old.version, bytes: field)
        var bytes = try PlanarRuntimeProbeContext.byteWork()
        _ = try context.codec.decode(record, work: &bytes)
        let forged = try RuntimeCheckpoint(model: checkpoint.model, continuation: checkpoint.continuation,
            physical: checkpoint.physical, contributors: [record], random: checkpoint.random, acceptedSteps: checkpoint.acceptedSteps)
        let codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()
        let wire = try codec.encode(forged, capacity: context.session.configuration.capacity)
        var refused = false
        do throws(RuntimeFailure) { _ = try context.session.restart(wire, codec: codec) }
        catch {
            try require(error.code == .invalidState && error.lastAccepted == prefix)
            refused = true
        }
        try require(refused && context.session.snapshot() == prefix)
    }
}
