
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public struct RuntimeMechanismBreak: MechanismBreaking {
    public init() {}
    public func prepare(source:RuntimeAcceptedState,transition:DetachedLeafTransition,reaction:ConstrainedMotion,thresholdSI:Double,
                        eventID:UInt64,maximumEventBytes:Int,work:inout NumericalWork) throws(MechanismError) -> PreparedMechanismBreak? {
        guard !Task.isCancelled else { throw .cancelled }
        try MechanismArithmetic.numerical { () throws(NumericalError) in
            try work.requireStorage(try NumericalWork.product(reaction.sourceSnapshot.bodies.count,128))
            try work.chargeOperations(try NumericalWork.sum(try NumericalWork.product(reaction.sourceSnapshot.bodies.count,8),try NumericalWork.sum(reaction.basis.joints.count,reaction.generalizedReaction.count)))
        }
        guard source.physical == transition.source,source.checkpoint.physical == transition.source.state,
              reaction.time == source.checkpoint.physical.time,reaction.sourceVelocity == source.checkpoint.physical.v,
              reaction.basis == reaction.sourceSnapshot.tree.layout,reaction.layout.revision == source.physical.stamp.revision,
              reaction.sourceSnapshot.tree.revision == source.physical.stamp.revision,
              let entry=reaction.basis.joints.first(where:{$0.joint == transition.removedJoint}),entry.velocities.count == 1,
              let original=reaction.sourceSnapshot.tree.joints.first(where:{$0.id == transition.removedJoint}),
              original.childBody == transition.body,thresholdSI.isFinite,thresholdSI >= 0,
              reaction.generalizedReaction.count == reaction.basis.velocityCount else { throw .staleBinding }
        // FIXME(INCOMPLETE_IMPLEMENTATION): This production gate admits one accepted break event. Multiple break/law topology histories need complete event migration and replay authority before admitting a second event.
        guard !source.checkpoint.contributors.contains(where:{$0.id == "mechanics.mechanisms.break.v1"}) else { throw .unsupportedTopologyReplacement }
        for body in reaction.sourceSnapshot.bodies {
            let original:BodyKinematics
            do { original=try transition.sourceSnapshot.body(body.body) } catch { throw .staleBinding }
            guard original.motion.pose == body.motion.pose,original.motion.velocity == body.motion.velocity else { throw .staleBinding }
        }
        let observed=reaction.generalizedReaction[entry.velocities.start]
        guard observed.isFinite else { throw .nonfinite }
        if abs(observed) <= thresholdSI { return nil }
        let metric:MechanismBreakEvent.Metric
        switch (original.manifold.kind,reaction.temporalMeaning) {
        case (.revolute,.accelerationForce): metric = .torque
        case (.prismatic,.accelerationForce): metric = .force
        case (.revolute,.instantaneousVelocityImpulse): metric = .angularImpulse
        case (.prismatic,.instantaneousVelocityImpulse): metric = .linearImpulse
        default: throw .unsupportedReactionFidelity
        }
        let event=try MechanismBreakEvent(id:eventID,source:transition.source.stamp,target:transition.target.stamp,joint:transition.removedJoint,
            connector:transition.freeConnector,acceptedTime:reaction.time,metric:metric,observed:observed,threshold:thresholdSI,maximumMetadataBytes:maximumEventBytes)
        let contributor=try MechanismBreakContributor(event:event,target:transition.target,maximumBytes:maximumEventBytes)
        return PreparedMechanismBreak(source:source,transition:transition,contributor:contributor)
    }
    @inline(never)
    public func publish(_ prepared:PreparedMechanismBreak,session:any RuntimeModelReplacing,configuration:RuntimeConfiguration,
                        contributors:[RuntimeContributorState],checkpoints:any RuntimeCheckpointHandling) throws(MechanismError) -> RuntimeAcceptedState {
        guard !Task.isCancelled else { throw .cancelled }
        guard contributors.count <= configuration.capacity.maximumContributors else { throw .capacityExceeded }
        var metadata=0,bytes=0
        for record in contributors {
            for _ in record.id.utf8 { guard metadata < configuration.capacity.maximumMetadataBytes else { throw .capacityExceeded };metadata+=1 }
            bytes=try MechanismArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(bytes,record.bytes.count) }
            guard bytes <= configuration.capacity.maximumContributorBytes else { throw .capacityExceeded }
        }
        guard contributors.count == configuration.requiredContributors.count,
              contributors.contains(prepared.contributor.record),configuration.requiredContributors.contains(prepared.contributor.schema) else { throw .staleBinding }
        for record in prepared.source.checkpoint.contributors where record.category != .integrator {
            guard contributors.contains(record) else { throw .staleBinding }
        }
        // The old equation-bound chart is explicitly invalidated, never reused on a free 7/6 layout.
        for record in prepared.source.checkpoint.contributors where record.category == .integrator {
            guard !contributors.contains(where:{$0.id == record.id}) else { throw .unsupportedChart }
        }
        let request=RuntimeModelReplacement(expectedSource:prepared.source.checkpoint,model:prepared.transition.target,
            physical:prepared.transition.physical,contributors:contributors,configuration:configuration,checkpoints:checkpoints)
        do throws(RuntimeFailure) { return try session.replaceModel(request) } catch { throw .runtime(error) }
    }
}
