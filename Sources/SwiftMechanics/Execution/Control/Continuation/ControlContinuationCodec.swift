internal struct ControlContinuationCodec: Sendable {
    let schema:RuntimeContributorSchema
    let prefix:[UInt8]
    let clock:ControlClock
    init(plant:PrismaticControlPlant,controller:SampledController,clock:ControlClock,policy:ControlPolicy,work:inout NumericalWork) throws(ControlFailure) {
        let texts=[plant.model.stamp.identity,plant.port.binding.actuator.key,plant.port.binding.joint.key,plant.port.binding.frame.key,
                   plant.port.parentAnchorFrame.key]
        var length=0
        for text in texts {
            try ControlArithmetic.metadata(text,policy:policy,work:&work)
            let add=length.addingReportingOverflow(text.utf8.count+8)
            guard !add.overflow else { throw ControlFailure(.capacity,phase:"codec") };length=add.partialValue
        }
        let size=length.addingReportingOverflow(512)
        guard !size.overflow,size.partialValue <= policy.maximumPayloadBytes else { throw ControlFailure(.capacity,phase:"codec") }
        try ControlArithmetic.charge(size.partialValue,work:&work,policy:policy)
        do { try work.requireStorage(size.partialValue) } catch { throw ControlFailure(.numerical(error),phase:"codec") }
        var data:[UInt8]=[];data.reserveCapacity(size.partialValue)
        for text in texts { Self.put(UInt64(text.utf8.count),into:&data);data.append(contentsOf:text.utf8) }
        let law=controller.servo,binding=law.binding
        for v in [plant.model.stamp.revision,binding.lawRevision,binding.continuationKey,clock.maximumTicks,UInt64(controller.law == .servo ? 0:1),UInt64(controller.mode.rawValue)] { Self.put(v,into:&data) }
        for v in [clock.epochSeconds,clock.periodSeconds,clock.maximumTimeSeconds,plant.disturbanceNewtons,plant.movingMass,
                  law.positionGain,law.velocityGain,law.integralGain,law.integralLimit,law.effortLimit,law.speedLimit,
                  law.positionDeadband,law.velocityDeadband,law.filterTimeConstant,controller.positionAccelerationGain,controller.rateAccelerationGain,
                  policy.maximumPositionMeters,policy.maximumRateMetersPerSecond,policy.agreement.absolute,policy.agreement.relative,
                  binding.stateDomain.primaryLower,binding.stateDomain.primaryUpper,binding.stateDomain.secondaryLower,binding.stateDomain.secondaryUpper] { Self.put(v.bitPattern,into:&data) }
        prefix=data;self.clock=clock
        do { schema=try RuntimeContributorSchema(id:"mechanics.control.sampled.v1",category:.controller,version:1,maximumBytes:data.count+160) }
        catch { throw ControlFailure(.runtime(error),phase:"codec") }
        guard schema.maximumBytes <= policy.maximumPayloadBytes else { throw ControlFailure(.capacity,phase:"codec") }
    }
    func record(_ h:ControlHistory) throws(RuntimeFailure) -> RuntimeContributorState {
        var bytes=prefix;bytes.reserveCapacity(schema.maximumBytes)
        for v in [h.tick,UInt64(h.issued ? 1:0),UInt64(h.pending ? 1:0),UInt64(h.clipped ? 1:0)] { Self.put(v,into:&bytes) }
        for v in [h.sourceTime,h.sampleTickTime,h.intervalEnd,h.sampledPosition,h.sampledRate,h.requestedEffort,h.heldEffort,
                  h.nominalSampledWork,h.actuatorIntervalWork,h.disturbanceIntervalWork,h.initialKineticEnergy,h.endpointKineticEnergy,
                  h.forceResidual,h.endpointPosition,h.endpointRate] { guard v.isFinite else { throw RuntimeFailure(.invalidContributor,message:"Nonfinite controller history.") };Self.put(v.bitPattern,into:&bytes) }
        return try RuntimeContributorState(id:schema.id,category:schema.category,version:schema.version,bytes:bytes)
    }
    func history(_ record:RuntimeContributorState) throws(RuntimeFailure) -> ControlHistory {
        guard record.id == schema.id,record.category == .controller,record.version == 1,record.bytes.count == prefix.count+152,
              record.bytes.starts(with:prefix) else { throw RuntimeFailure(.invalidContributor,message:"Controller configuration/payload differs.") }
        var index=prefix.count
        let tick=Self.get(record.bytes,&index),issued=Self.get(record.bytes,&index),pending=Self.get(record.bytes,&index),clipped=Self.get(record.bytes,&index)
        guard issued <= 1,pending <= 1,clipped <= 1 else { throw RuntimeFailure(.invalidContributor,message:"Controller history flag invalid.") }
        var values:[Double]=[];values.reserveCapacity(15)
        for _ in 0..<15 { let v=Double(bitPattern:Self.get(record.bytes,&index));guard v.isFinite else { throw RuntimeFailure(.invalidContributor,message:"Nonfinite controller history.") };values.append(v) }
        return ControlHistory(tick:tick,issued:issued == 1,pending:pending == 1,sourceTime:values[0],sampleTickTime:values[1],intervalEnd:values[2],
            sampledPosition:values[3],sampledRate:values[4],requestedEffort:values[5],heldEffort:values[6],nominalSampledWork:values[7],
            actuatorIntervalWork:values[8],disturbanceIntervalWork:values[9],initialKineticEnergy:values[10],endpointKineticEnergy:values[11],
            forceResidual:values[12],endpointPosition:values[13],endpointRate:values[14],clipped:clipped == 1)
    }
    private static func put(_ value:UInt64,into bytes:inout [UInt8]) { for shift in stride(from:0,to:64,by:8) { bytes.append(UInt8(truncatingIfNeeded:value >> shift)) } }
    private static func get(_ bytes:[UInt8],_ index:inout Int) -> UInt64 {
        var v:UInt64=0;for shift in stride(from:0,to:64,by:8) { v |= UInt64(bytes[index]) << shift;index += 1 };return v
    }
}
