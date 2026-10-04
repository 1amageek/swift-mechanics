@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct SleepTopologyWakeEncoding {
    private var payload:TopologyPayload
    private mutating func word(_ value:UInt64,_ work:inout NumericalWork) throws(TopologyReleaseFailure) {
        try TopologyArithmetic.charge(8,&work);try payload.put(value)
    }
    private mutating func text(_ value:String,_ work:inout NumericalWork) throws(TopologyReleaseFailure) {
        try TopologyArithmetic.charge(try TopologyArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(8,value.utf8.count) },&work)
        try payload.put(value)
    }
    private mutating func raw(_ value:[UInt8],_ work:inout NumericalWork) throws(TopologyReleaseFailure) {
        try TopologyArithmetic.charge(try TopologyArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(8,value.count) },&work)
        try payload.put(value)
    }
    private mutating func scalars(_ values:[Double],_ work:inout NumericalWork) throws(TopologyReleaseFailure) {
        try word(UInt64(values.count),&work);for value in values { guard value.isFinite else { throw .invalidInput };try word(value.bitPattern,&work) }
    }
    @inline(never)
    static func encode(retirement:PreparedSleepTopologyRetirement,transition:NonlinearReconciledSubtreeRelease,
                       event:TopologyAcceptedEvent,policy:TopologyContinuationPolicy,work:inout NumericalWork) throws(TopologyReleaseFailure) -> [UInt8] {
        try TopologyArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(try NumericalWork.sum(policy.maximumBytes/8,1)) }
        var data=SleepTopologyWakeEncoding(payload:try TopologyPayload(policy:policy))
        try data.word(1,&work);try data.text("sleep-topology-wake-catalog-v1",&work);try data.raw(retirement.sourceLawSignature,&work)
        for text in [transition.descriptor.identity,transition.descriptor.chart,transition.descriptor.model.identity] { try data.text(text,&work) }
        try data.word(transition.descriptor.model.revision,&work)
        let source=retirement.source.checkpoint
        for value in [source.acceptedSteps,source.random.seed,source.random.state,source.random.draws,event.id,event.acceptedSequence,event.acceptedTime.bitPattern,event.observed.bitPattern] { try data.word(value,&work) }
        for text in [source.continuation.build,source.continuation.backend,source.continuation.precision,event.rule.joint.key,event.rule.connector.key,event.rule.parentAnchor.key,event.rule.childAnchor.key,event.rule.subtreeRoot.key] { try data.text(text,&work) }
        try data.word(UInt64(event.rule.metric.rawValue),&work);try data.word(event.rule.threshold.bitPattern,&work)
        try data.scalars(source.physical.q,&work);try data.scalars(source.physical.v,&work);try data.scalars(source.physical.acceleration,&work)
        try data.word(UInt64(retirement.retiredConstraintIDs.count),&work);for id in retirement.retiredConstraintIDs { try data.word(id,&work) }
        try data.word(retirement.retiredEffort.bitPattern,&work);try data.scalars(retirement.targetDrive,&work)
        try data.word(UInt64(retirement.release.mappings.count),&work)
        for mapping in retirement.release.mappings {
            try data.text(mapping.joint.key,&work)
            for value in [mapping.source.positions.start,mapping.source.positions.count,mapping.source.velocities.start,mapping.source.velocities.count,
                          mapping.target.positions.start,mapping.target.positions.count,mapping.target.velocities.start,mapping.target.velocities.count] { try data.word(UInt64(value),&work) }
        }
        try data.scalars(transition.physical.q,&work);try data.scalars(transition.physical.v,&work);try data.scalars(transition.physical.acceleration,&work)
        try data.word(transition.physical.time.bitPattern,&work)
        try data.word(UInt64(transition.motion.rowIDs.count),&work);for id in transition.motion.rowIDs { try data.word(id,&work) }
        try data.scalars(transition.motion.values,&work);try data.scalars(transition.motion.generalizedReaction,&work)
        return data.payload.bytes
    }
}
