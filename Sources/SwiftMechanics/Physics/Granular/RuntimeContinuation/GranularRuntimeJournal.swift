public final class GranularRuntimeJournal: GranularRuntimeContinuing, Sendable {
    public let source: GranularRuntimeSource
    public var schema: RuntimeContributorSchema { source.schema }
    public init(source: GranularRuntimeSource) { self.source=source }
    public func initial(work: inout GranularRuntimeWork) throws(GranularRuntimeError) -> GranularRuntimeContinuation {
        try admit(&work);return GranularRuntimeContinuation(source:source,particles:source.initial,random:source.initial.random,choices:[])
    }
    @inline(never)
    public func encode(_ continuation: GranularRuntimeContinuation, work: inout GranularRuntimeWork) throws(GranularRuntimeError) -> RuntimeContributorState {
        try admit(&work)
        guard continuation.source === source,continuation.particles.model === source.initial.model,
              continuation.gravityChoiceIndices.count <= source.maximumAcceptedSteps,
              continuation.particles.steps == UInt64(continuation.gravityChoiceIndices.count) else { throw .staleSource }
        let size=try GranularJournalWire.sum(source.signature.count,GranularJournalWire.sum(48,GranularJournalWire.product(8,continuation.gravityChoiceIndices.count)))
        try work.charge(source.signature.count)
        var bytes=source.signature
        bytes.reserveCapacity(size)
        for value in [continuation.particles.timeSeconds.bitPattern,continuation.particles.steps,
                      continuation.random.seed,continuation.random.state,continuation.random.draws,UInt64(continuation.gravityChoiceIndices.count)] {
            try GranularJournalWire.word(value,bytes:&bytes,maximum:schema.maximumBytes,work:&work)
        }
        for choice in continuation.gravityChoiceIndices { try GranularJournalWire.word(choice,bytes:&bytes,maximum:schema.maximumBytes,work:&work) }
        try source.poll(work)
        do throws(RuntimeFailure) { return try RuntimeContributorState(id:schema.id,category:schema.category,version:schema.version,bytes:bytes) }
        catch { throw .runtime(error) }
    }
    @inline(never)
    public func decode(_ record: RuntimeContributorState, work: inout GranularRuntimeWork) throws(GranularRuntimeError) -> GranularRuntimeContinuation {
        try admit(&work)
        var metadata=source.maximumMetadataBytes
        for _ in record.id.utf8 { try work.charge(3);guard metadata > 0 else { throw .capacityExceeded };metadata-=1 }
        guard record.id == schema.id,record.category == schema.category,record.version == schema.version else { throw .staleSource }
        guard record.bytes.count <= schema.maximumBytes else { throw .capacityExceeded }
        let minimum=try GranularJournalWire.sum(source.signature.count,48)
        guard record.bytes.count >= minimum else { throw .malformedJournal }
        try work.charge(record.bytes.count)
        for i in source.signature.indices { try source.poll(work);guard record.bytes[i] == source.signature[i] else { throw .staleSource } }
        var cursor=source.signature.count
        let time=GranularJournalWire.read(record.bytes,cursor:&cursor),steps=GranularJournalWire.read(record.bytes,cursor:&cursor)
        let seed=GranularJournalWire.read(record.bytes,cursor:&cursor),state=GranularJournalWire.read(record.bytes,cursor:&cursor)
        let draws=GranularJournalWire.read(record.bytes,cursor:&cursor),count=GranularJournalWire.read(record.bytes,cursor:&cursor)
        guard count <= UInt64(source.maximumAcceptedSteps),steps == count else { throw .malformedJournal }
        let length=try GranularJournalWire.sum(minimum,GranularJournalWire.product(8,Int(count)))
        guard record.bytes.count == length else { throw .malformedJournal }
        var current=source.initial,random=source.initial.random,choices:[UInt64]=[],workspace=GranularWorkspace()
        choices.reserveCapacity(Int(count))
        for _ in 0..<Int(count) {
            try source.poll(work)
            let choice=GranularJournalWire.read(record.bytes,cursor:&cursor),draw: UInt64
            do throws(RuntimeFailure) { draw=try random.next() } catch { throw .runtime(error) }
            guard choice == draw % UInt64(source.gravityChoices.count) else { throw .malformedJournal }
            let result=try step(current,choice:choice,workspace:&workspace,work:&work)
            current=result.state;choices.append(choice)
        }
        guard current.timeSeconds.bitPattern == time,current.steps == steps,random.seed == seed,
              random.state == state,random.draws == draws else { throw .malformedJournal }
        try source.poll(work)
        return GranularRuntimeContinuation(source:source,particles:current,random:random,choices:choices)
    }
    internal func admit(_ work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        try source.poll(work);guard work.physics.matches(source.physicsBudget),work.nativeBudgetsMatch() else { throw .staleSource }
        try work.reserve(source.requiredStorageBytes)
    }
    @inline(never)
    internal func step(_ state: GranularState,choice: UInt64,workspace: inout GranularWorkspace,
                       work: inout GranularRuntimeWork) throws(GranularRuntimeError) -> GranularStepResult {
        try source.poll(work);try work.admitPhysics()
        do throws(GranularError) {
            return try ReferenceGranularEvolution().step(accepted:state,timeStepSeconds:source.timeStepSeconds,
                gravity:source.gravityChoices[Int(choice)],policy:source.policy,workspace:&workspace,
                numericalWork:&work.numerical,collisionWork:&work.collision,contactWork:&work.contact,supplierWork:&work.suppliers)
        } catch { throw .physical(error) }
    }
}
