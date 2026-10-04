@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
extension CheckpointedMechanismSleep: MechanismSleepTopologyRetiring {
    @inline(never)
    public func prepareRetirement(source:RuntimeAcceptedState,sourceConfiguration:RuntimeConfiguration,
        checkpoints:any RuntimeCheckpointHandling,release:SubtreeRelease,retiredConstraintIDs:[UInt64],
        targetConstraints:QuadraticConstraintSystem,targetVelocityLayout:ConstraintCoordinateLayout,
        cancellation:RuntimeCancellationSource?,work:inout NumericalWork) throws(SleepTopologyFailure) -> PreparedSleepTopologyRetirement {
        do throws(SleepTopologyFailureReason) {
            let authority=try admitTopologySource(source,configuration:sourceConfiguration,checkpoints:checkpoints,
                release:release,cancellation:cancellation,work:&work)
            let drive=try SleepTopologyLawMapping.validate(owner:self,authority:authority,retired:retiredConstraintIDs,
                constraints:targetConstraints,velocity:targetVelocityLayout,work:&work)
            let signature=try SleepTopologySourceSignature.encode(owner:self,source:source,history:authority.history,
                maximum:min(policy.maximumIdentityBytes,sourceConfiguration.capacity.maximumContributorBytes),work:&work)
            try topologyPoll(cancellation)
            return PreparedSleepTopologyRetirement(admission:_SleepTopologyRetirementAdmission(source:source,release:release,
                record:authority.record,history:authority.history,retired:retiredConstraintIDs,
                effort:authority.history.drive[authority.cut],constraints:targetConstraints,layout:targetVelocityLayout,
                drive:drive,signature:signature))
        } catch { throw SleepTopologyFailure(error,source:source,work:work) }
    }
    @inline(never)
    private func admitTopologySource(_ source:RuntimeAcceptedState,configuration:RuntimeConfiguration,
        checkpoints:any RuntimeCheckpointHandling,release:SubtreeRelease,cancellation:RuntimeCancellationSource?,
        work:inout NumericalWork) throws(SleepTopologyFailureReason) -> SleepTopologySourceAuthority {
        try topologyPoll(cancellation)
        guard source.physical.stamp == release.source.stamp,SleepTopologyLawMapping.same(source.physical.state,release.source.state),
              SleepTopologyLawMapping.same(source.checkpoint.physical,release.source.state),
              release.sourceModel.descriptor == model.descriptor,release.sourceModel.tree.layout == model.tree.layout,
              source.physical.stamp == model.stamp,source.checkpoint.model == model.stamp,
              source.checkpoint.acceptedSteps < UInt64.max,model.stamp.revision < UInt64.max,
              release.target.stamp.identity == model.stamp.identity,release.target.stamp.revision == model.stamp.revision+1,
              source.checkpoint.contributors.count <= configuration.capacity.maximumContributors,
              source.checkpoint.contributors.count == configuration.requiredContributors.count,
              let record=source.checkpoint.contributors.first(where:{$0.id == schema.id}),
              let integration=source.checkpoint.contributors.first(where:{$0.id == continuation.schema.id}),
              let cut=model.tree.layout.joints.first(where:{$0.joint == release.removedJoint}),
              cut.positions.count == 1,cut.velocities.count == 1,
              model.tree.rootBase == .fixed,model.tree.layout.positionCount == model.tree.layout.velocityCount else { throw .staleSource }
        guard model.tree.layout.joints.allSatisfy({$0.positions.count == 1 && $0.velocities.count == 1}) else { throw .unsupportedDomain }
        guard source.checkpoint.continuation == configuration.continuation,configuration.requiredContributors.contains(schema),
              configuration.requiredContributors.contains(continuation.schema) else { throw .staleSource }
        for (record,declared) in zip(source.checkpoint.contributors,configuration.requiredContributors) {
            try SleepTopologyLawMapping.charge(1,&work)
            guard record.id == declared.id,record.category == declared.category,record.version == declared.version,
                  record.bytes.count <= declared.maximumBytes else { throw .staleSource }
        }
        try SleepTopologyLawMapping.charge(try SleepTopologyLawMapping.sum(record.bytes.count,integration.bytes.count),&work)
        let history:MechanismSleepHistory,stored:IntegrationHistory
        do throws(RuntimeFailure) {
            history=try associated(record,physical:source.checkpoint.physical,sequence:source.checkpoint.acceptedSteps)
            stored=try continuation.history(integration)
        } catch { throw .runtime(error) }
        guard history.asleep.allSatisfy({$0}),source.checkpoint.physical.acceleration.allSatisfy({$0 == 0}),
              history.velocity.allSatisfy({$0 == 0}),stored.acceptedSteps == source.checkpoint.acceptedSteps,
              stored.acceptedTime.bitPattern == source.checkpoint.physical.time.bitPattern,
              history.acceptedTime.bitPattern == source.checkpoint.physical.time.bitPattern,
              SleepTopologyLawMapping.same(stored.acceptedPoint,source.checkpoint.physical.q+source.checkpoint.physical.v),
              SleepTopologyLawMapping.same(history.position,source.checkpoint.physical.q),
              SleepTopologyLawMapping.same(history.velocity,source.checkpoint.physical.v) else { throw .staleSource }
        try topologyEquilibrium(source.checkpoint.physical,drive:history.drive,cancellation:cancellation,work:&work)
        try topologySourceContext(source,configuration:configuration,checkpoints:checkpoints,cancellation:cancellation,work:&work)
        return SleepTopologySourceAuthority(source:source,release:release,record:record,history:history,cut:cut.positions.start)
    }
    @inline(never)
    private func topologyEquilibrium(_ physical:KinematicState,drive:[Double],cancellation:RuntimeCancellationSource?,
                                     work:inout NumericalWork) throws(SleepTopologyFailureReason) {
        try topologyPoll(cancellation)
        do throws(RuntimeFailure) {
            guard let proof=try restCertificate(physical:physical,drive:drive,work:&work),!proof.groups.isEmpty else {
                throw RuntimeFailure(.invalidState,message:"Sleep retirement has no original stationary equilibrium.")
            }
        } catch { throw .runtime(error) }
        try topologyPoll(cancellation)
    }
    @inline(never)
    private func topologySourceContext(_ source:RuntimeAcceptedState,configuration:RuntimeConfiguration,
        checkpoints:any RuntimeCheckpointHandling,cancellation:RuntimeCancellationSource?,work:inout NumericalWork) throws(SleepTopologyFailureReason) {
        try SleepTopologyLawMapping.charge(1,&work)
        do throws(RuntimeFailure) {
            let admitted=try checkpoints.admit(source.checkpoint,model:model,configuration:configuration,cancellation:cancellation)
            guard admitted == source else { throw RuntimeFailure(.invalidOwnerAccess,message:"Enriched source admission altered its exact accepted prefix.") }
        } catch { throw .runtime(error) }
    }
    private func topologyPoll(_ cancellation:RuntimeCancellationSource?) throws(SleepTopologyFailureReason) {
        do throws(RuntimeFailure) { if let cancellation { try cancellation.check() };try sleepCheck() }
        catch { throw .runtime(error) }
    }
}

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct _SleepTopologyRetirementAdmission: Sendable {
    let source:RuntimeAcceptedState;let release:SubtreeRelease;let record:RuntimeContributorState;let history:MechanismSleepHistory
    let retired:[UInt64];let effort:Double;let constraints:QuadraticConstraintSystem;let layout:ConstraintCoordinateLayout
    let drive:[Double];let signature:[UInt8]
    fileprivate init(source:RuntimeAcceptedState,release:SubtreeRelease,record:RuntimeContributorState,history:MechanismSleepHistory,
        retired:[UInt64],effort:Double,constraints:QuadraticConstraintSystem,layout:ConstraintCoordinateLayout,drive:[Double],signature:[UInt8]) {
        self.source=source;self.release=release;self.record=record;self.history=history;self.retired=retired;self.effort=effort
        self.constraints=constraints;self.layout=layout;self.drive=drive;self.signature=signature
    }
}
