import MechanicsCompiler
import MechanicsRuntime

public struct HybridEventCatalog: Equatable, Sendable {
    public let model: ModelStamp
    public let geometryRevision: UInt64
    public let eventIDs: [UInt64]
    /// Provider-owned exact chart, geometry placements, smooth equation and crossing-coverage configuration.
    public let providerSignature: [UInt8]
    public init(model: ModelStamp, geometryRevision: UInt64, eventIDs: [UInt64], providerSignature: [UInt8],
                policy: HybridEvolutionPolicy) throws(HybridError) {
        guard !eventIDs.isEmpty, eventIDs.count <= policy.maximumCatalogEvents, !providerSignature.isEmpty,
              providerSignature.count <= policy.maximumContinuationBytes else { throw .capacityExceeded }
        do throws(RuntimeFailure) {
            var bounds=HybridByteBounds(maximum:policy.maximumContinuationBytes)
            try bounds.reserve(providerSignature.count); try bounds.words(eventIDs.count)
            _=try bounds.text(model.identity,identifierLimit:policy.maximumContinuationBytes,prefixed:false)
        } catch { throw .runtime(error) }
        let sorted=eventIDs.sorted()
        for i in 1..<sorted.count { guard sorted[i-1] != sorted[i] else { throw .invalidInput } }
        self.model=model; self.geometryRevision=geometryRevision; self.eventIDs=sorted; self.providerSignature=providerSignature
    }
}
