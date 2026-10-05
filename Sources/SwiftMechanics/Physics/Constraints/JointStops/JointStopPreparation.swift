internal enum JointStopPreparation {
    static func admit(_ input: JointStopInput, policy: JointStopPolicy,
                      work: inout NumericalWork) throws(JointStopFailure) {
        let a=JointStopArithmetic.self, tree=input.model.tree, state=input.state.state
        try a.check(policy)
        let b=tree.bodies.count, n=tree.layout.velocityCount
        guard b <= policy.observations.maximumBodies, b <= policy.admission.capacity.maximumBodies,
              n <= policy.observations.maximumCoordinates, n <= policy.constraints.maximumCoordinates,
              n <= policy.admission.capacity.maximumVelocities, input.inertias.count <= policy.admission.capacity.maximumBodies,
              tree.layout.positionCount <= policy.observations.maximumCoordinates,
              state.q.count <= policy.observations.maximumCoordinates, state.v.count <= policy.observations.maximumCoordinates,
              state.acceleration.count <= policy.observations.maximumCoordinates,
              policy.impulseScales.count <= policy.observations.maximumCoordinates,
              policy.mass.coordinateScales.count <= policy.observations.maximumCoordinates,
              state.prescribedAnchors.count <= (try a.product(2,b)) else { throw JointStopFailure(.capacityExceeded) }
        guard input.inertias.count == b, state.q.count == tree.layout.positionCount, state.v.count == n,
              state.acceleration.count == n, policy.impulseScales.count == n,
              policy.mass.coordinateScales.count == n else { throw JointStopFailure(.invalidShape) }
        for text in [input.model.stamp.identity,input.state.stamp.identity,input.definition.model.identity,input.definition.joint.key] {
            try a.metadata(text,policy:policy,work:&work)
        }
        guard input.definition.model == input.model.stamp, input.state.stamp == input.model.stamp,
              state.revision == tree.revision, tree.revision == policy.constraints.expectedLayoutRevision,
              input.expectedTimeSeconds.isFinite, input.expectedTimeSeconds == state.time else { throw JointStopFailure(.staleSource) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Extended/constrained, floating/planar or prescribed sources reach this stop admission.
        // Original projected mass/boundary work and source-specific stop evidence are required before success.
        guard n > 0, tree.rootBase == .fixed, input.model.descriptor.rootAuthority == .fixed,
              tree.layout.positionCount == n, tree.bodies.allSatisfy({$0.dimension == .spatial}),
              input.model.descriptor.extensions.isEmpty, input.model.descriptor.features.isEmpty,
              state.prescribedAnchors.isEmpty else { throw JointStopFailure(.unsupportedDomain) }
        try a.charge(a.product(16,try a.product(b,b)),&work)
        for record in tree.joints {
            try a.check(policy)
            guard let mechanical=input.model.descriptor.joints.first(where:{$0.record.id == record.id}),
                  mechanical.record == record else { throw JointStopFailure(.staleSource) }
            // FIXME(INCOMPLETE_IMPLEMENTATION): Screw/multiaxis/manifold tree joints reach this scalar stop path.
            // Original chart rate/subspace and corresponding stop-law evidence are required before success.
            switch record.manifold.kind {
            case .fixed:
                guard mechanical.authority == .fixed else { throw JointStopFailure(.unsupportedDomain) }
            case .revolute, .prismatic:
                guard mechanical.authority == .dynamicState, record.manifold.positionCount == 1,
                      record.manifold.velocityCount == 1 else { throw JointStopFailure(.unsupportedDomain) }
            default: throw JointStopFailure(.unsupportedDomain)
            }
            // FIXME(INCOMPLETE_IMPLEMENTATION): Prescribed joint anchors do not supply stop impulse work in this path.
            // Actual prescribed boundary momentum/work must be computed before these anchors can succeed.
            for anchor in [record.parentAnchor,record.childAnchor] {
                if case .prescribed=anchor.placement { throw JointStopFailure(.unsupportedDomain) }
            }
        }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Periodic scalar stop definitions reach this preparation method.
        // An explicit angular branch/discontinuity event contract is required before periodic wrap can succeed.
        if case .periodic=input.definition.wrap { throw JointStopFailure(.unsupportedDomain) }
        let law=input.definition.restitutionLaw
        // FIXME(INCOMPLETE_IMPLEMENTATION): Continuous/cohesive/resistive stop selections reach this hard impulse path.
        // Their original evolution/impulse compatibility must be implemented before successful stop publication.
        guard case .separateImpact=law.lossPolicy, law.parameters.friction == .none, law.parameters.cohesion == .none,
              law.parameters.resistance.rollingCoefficient == 0, law.parameters.resistance.spinningCoefficient == 0 else {
            throw JointStopFailure(.unsupportedDomain)
        }
        try a.storage(a.reserved(input),&work)
    }

    @inline(never)
    static func observed(_ input: JointStopInput, state: CompiledKinematicState, policy: JointStopPolicy,
                         work: inout NumericalWork) throws(JointStopFailure) -> (ObservationSource, JointEncoderObservation) {
        let a=JointStopArithmetic.self, reserved=try a.reserved(input)
        try a.check(policy); try a.treeCharge(input,&work)
        var local=try a.seeded(work,reserved:reserved); let before=local
        var source: ObservationSource?, encoder: JointEncoderObservation?, failure: ObservationError?
        do throws(ObservationError) {
            source=try ReferenceObservationSourcePreparer().prepare(model:input.model,state:state,solved:nil,policy:policy.observations,work:&local)
            if let source { encoder=try ReferenceKinematicObserver().encoder(source:source,joint:input.definition.joint,policy:policy.observations,work:&local) }
        } catch { failure=error }
        try a.reconcile(local,before:before,reserved:reserved,work:&work)
        if let failure { throw JointStopFailure(.observation(failure),failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable) }
        guard let source, let encoder, source.model.stamp == input.model.stamp, source.state == state,
              encoder.model == input.model.stamp, encoder.joint == input.definition.joint,
              encoder.timeSeconds == state.state.time else { throw JointStopFailure(.invalidSupplierOutput) }
        try a.check(policy); return (source,encoder)
    }

    @inline(never)
    static func make(_ input: JointStopInput, policy: JointStopPolicy,
                     work: inout NumericalWork) throws(JointStopFailure) -> PreparedJointStop {
        let a=JointStopArithmetic.self
        try admit(input,policy:policy,work:&work)
        let tree=input.model.tree, n=tree.layout.velocityCount
        guard let record=tree.joints.first(where:{$0.id == input.definition.joint}),
              let layout=tree.layout.joints.first(where:{$0.joint == input.definition.joint}) else { throw JointStopFailure(.unknownJoint) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Fixed target joints have no scalar stop coordinate.
        // A different physical lock/reaction operation is required before this target can produce an impulse.
        guard layout.positions.count == 1, layout.velocities.count == 1,
              record.manifold.kind == .revolute || record.manifold.kind == .prismatic else { throw JointStopFailure(.unsupportedDomain) }
        let (source,encoder)=try observed(input,state:input.state,policy:policy,work:&work)
        try validateEncoder(encoder,input:input,state:input.state,layout:layout,policy:policy,work:&work)
        let expected: PhysicalDimension=record.manifold.kind == .prismatic ? .length : .angle
        guard input.definition.coordinateUnit == expected,
              record.manifold.kind != .prismatic || input.definition.metersPerCoordinateUnit == 1 else { throw JointStopFailure(.unitMismatch) }
        let gaps: ScalarJointLimitResponse
        do throws(ConstraintError) {
            gaps=try ScalarJointPortEvaluator().limits(record.manifold,position:encoder.positions[0],velocity:encoder.coordinateRates[0],
                lower:input.definition.lower,upper:input.definition.upper,mode:.rowsOnly,impact:.none,wrap:.unwrapped,
                policy:policy.constraints,work:&work)
        } catch { throw JointStopFailure(.constraints(error)) }
        guard gaps.lowerJacobian == 1, gaps.upperJacobian == -1,
              gaps.lowerGap.isFinite, gaps.upperGap.isFinite, gaps.lowerGapRate.isFinite, gaps.upperGapRate.isFinite,
              gaps.compliantEffort == nil else { throw JointStopFailure(.invalidSupplierOutput) }
        try a.charge(a.product(2,n),&work)
        var lower=[Double](repeating:0,count:n), upper=lower
        lower[layout.velocities.start]=try a.finite(input.definition.metersPerCoordinateUnit*gaps.lowerJacobian)
        upper[layout.velocities.start]=try a.finite(input.definition.metersPerCoordinateUnit*gaps.upperJacobian)
        try a.check(policy)
        return PreparedJointStop(input:input,source:source,encoder:encoder,layout:layout,gaps:gaps,lowerRow:lower,upperRow:upper)
    }

    static func validateEncoder(_ encoder: JointEncoderObservation, input: JointStopInput, state: CompiledKinematicState,
                                layout: JointCoordinateLayout, policy: JointStopPolicy,
                                work: inout NumericalWork) throws(JointStopFailure) {
        let a=JointStopArithmetic.self
        try a.charge(a.sum(32,input.model.tree.joints.count),&work)
        let unit=input.definition.coordinateUnit, rateUnit=PhysicalDimension(length:unit.length,time:-1,angle:unit.angle)
        let accelerationUnit=PhysicalDimension(length:unit.length,time:-2,angle:unit.angle)
        guard let record=input.model.tree.joints.first(where:{$0.id == input.definition.joint}) else { throw JointStopFailure(.unknownJoint) }
        guard encoder.positions.count == 1, encoder.coordinateRates.count == 1, encoder.velocities.count == 1,
              encoder.accelerations.count == 1, encoder.positionUnits == [unit], encoder.coordinateRateUnits == [rateUnit],
              encoder.velocityUnits == [rateUnit], encoder.accelerationUnits == [accelerationUnit],
              encoder.parentAnchorFrame == record.parentAnchor.frame, encoder.accelerationAuthority == .suppliedState,
              encoder.velocityConvention == .orderedAxisRates,
              encoder.positions[0] == state.state.q[layout.positions.start], encoder.velocities[0] == state.state.v[layout.velocities.start],
              encoder.accelerations[0] == state.state.acceleration[layout.velocities.start] else { throw JointStopFailure(.unitMismatch) }
        let error=abs(try a.finite(input.definition.metersPerCoordinateUnit*(encoder.coordinateRates[0]-encoder.velocities[0])))
        guard error <= policy.speedToleranceMetersPerSecond else { throw JointStopFailure(.normalRateRejected(value:error,threshold:policy.speedToleranceMetersPerSecond)) }
    }
}
