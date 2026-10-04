
internal enum ObservationArithmetic {
    static func core<T>(_ body: () throws(CoreError) -> T) throws(ObservationError) -> T {
        do throws(CoreError) { return try body() } catch { throw .core(error) }
    }
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(ObservationError) -> T {
        do throws(NumericalError) { return try body() } catch { throw .numerical(error) }
    }
    static func check(_ policy: ObservationPolicy) throws(ObservationError) {
        guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled }
    }
    static func metadata(_ texts: [String], policy: ObservationPolicy, work: inout NumericalWork) throws(ObservationError) {
        var count=0
        for text in texts {
            for _ in text.utf8 {
                guard count < policy.maximumMetadataBytes else { throw .capacityExceeded }
                count+=1; try numerical { () throws(NumericalError) in try work.chargeOperations(1) }
                try check(policy)
            }
        }
    }
    static func admit(_ source: ObservationSource, policy: ObservationPolicy, work: inout NumericalWork) throws(ObservationError) {
        try check(policy)
        let tree=source.snapshot.tree
        guard tree.bodies.count <= policy.maximumBodies,tree.layout.positionCount <= policy.maximumCoordinates,
              tree.layout.velocityCount <= policy.maximumCoordinates else { throw .capacityExceeded }
        try metadata([source.model.stamp.identity,tree.worldFrame.key],policy:policy,work:&work)
        for body in tree.bodies { try metadata([body.id.key,body.frame.key],policy:policy,work:&work) }
        // The independent per-record metadata bound is explicit; aggregate logical work remains caller bounded.
        for joint in tree.joints { try metadata([joint.id.key,joint.parentAnchor.frame.key,joint.childAnchor.frame.key],policy:policy,work:&work) }
        try numerical { () throws(NumericalError) in
            try work.requireStorage(try NumericalWork.sum(try NumericalWork.product(6,tree.layout.velocityCount),24))
            try work.chargeOperations(try NumericalWork.sum(tree.bodies.count,tree.joints.count))
        }
    }
    static func mounted(_ service:any KinematicObserving,source:ObservationSource,mount:ObservationMount,
                        policy:ObservationPolicy,work:inout NumericalWork) throws(ObservationError) -> MountedMotionObservation {
        try numerical { () throws(NumericalError) in try work.chargeOperations(1) }
        let before=work
        var result:MountedMotionObservation?,failure:ObservationError?
        do throws(ObservationError) { result=try service.motion(source:source,mount:mount,policy:policy,work:&work) } catch { failure=error }
        guard work.budget == before.budget,work.operations >= before.operations,work.iterations >= before.iterations,
              work.peakScalarStorage >= before.peakScalarStorage else { work=before;throw .supplierLedgerReplaced }
        if let failure { throw failure }
        guard let result,result.header.model == source.model.stamp,result.header.timeSeconds == source.state.state.time,
              result.header.sensor == mount.sensor,result.header.body == mount.body,result.header.expressedFrame == source.snapshot.tree.worldFrame else { throw .staleSource }
        try check(policy)
        let original=try ReferenceKinematicObserver().motion(source:source,mount:mount,policy:policy,work:&work)
        guard result.header.accelerationAuthority == original.header.accelerationAuthority,
              result.header.temporalMeaning == original.header.temporalMeaning else { throw .invalidSupplierEvidence }
        try motion(FrameMotion(pose:result.sensorToWorld,velocity:result.velocity,acceleration:result.acceleration),
            original:FrameMotion(pose:original.sensorToWorld,velocity:original.velocity,acceleration:original.acceleration),
            policy:policy,work:&work)
        return result
    }
    /// Exact original geometry is admitted; quaternion signs are compared through their rotation matrices.
    static func motion(_ supplied:FrameMotion,original:FrameMotion,policy:ObservationPolicy,
                       work:inout NumericalWork) throws(ObservationError) {
        try check(policy)
        try numerical { () throws(NumericalError) in
            try work.requireStorage(96)
            try work.chargeOperations(96)
        }
        let suppliedRotation=try core { () throws(CoreError) in try supplied.pose.rotation.matrix() }
        let originalRotation=try core { () throws(CoreError) in try original.pose.rotation.matrix() }
        guard supplied.pose.translation == original.pose.translation,suppliedRotation == originalRotation,
              supplied.velocity == original.velocity,supplied.acceleration == original.acceleration else { throw .invalidSupplierEvidence }
        try check(policy)
    }
    static func bind(_ motion: ConstrainedMotion, snapshot: KinematicSnapshot, velocity: [Double], policy: ObservationPolicy,
                     work: inout NumericalWork) throws(ObservationError) {
        guard motion.rowIDs.count <= policy.maximumReactionRows,
              motion.rowMultipliers.count <= policy.maximumReactionRows,
              motion.generalizedReaction.count <= policy.maximumCoordinates,motion.sourceVelocity.count <= policy.maximumCoordinates,
              motion.sourceSnapshot.bodies.count <= policy.maximumBodies,
              motion.basis.positionCount <= policy.maximumCoordinates,motion.basis.velocityCount <= policy.maximumCoordinates else { throw .capacityExceeded }
        try numerical { () throws(NumericalError) in try work.chargeOperations(try NumericalWork.sum(motion.rowIDs.count,motion.sourceVelocity.count)) }
        try metadata([motion.frame.key],policy:policy,work:&work)
        for body in motion.sourceSnapshot.bodies { try metadata([body.body.key,body.bodyFrame.key,body.worldFrame.key],policy:policy,work:&work) }
        for joint in motion.sourceSnapshot.tree.joints { try metadata([joint.id.key,joint.parentBody.key,joint.childBody.key,joint.parentAnchor.frame.key,joint.childAnchor.frame.key],policy:policy,work:&work) }
        guard motion.time == snapshot.time,motion.sourceSnapshot.time == snapshot.time,
              motion.basis == snapshot.tree.layout,motion.sourceSnapshot.tree.layout == snapshot.tree.layout,
              motion.sourceSnapshot.tree.revision == snapshot.tree.revision,motion.frame == snapshot.tree.worldFrame,
              motion.sourceSnapshot.tree.bodies == snapshot.tree.bodies,motion.sourceSnapshot.tree.joints == snapshot.tree.joints,
              motion.sourceSnapshot.tree.rootBase == snapshot.tree.rootBase,motion.sourceVelocity == velocity,
              motion.sourceSnapshot.bodies.count == snapshot.bodies.count else { throw .staleSource }
        for index in snapshot.bodies.indices {
            try check(policy)
            let actual=snapshot.bodies[index],original=motion.sourceSnapshot.bodies[index]
            let sameRotation=try core { () throws(CoreError) in try actual.motion.pose.rotation.matrix() == original.motion.pose.rotation.matrix() }
            guard actual.body == original.body,actual.bodyFrame == original.bodyFrame,actual.worldFrame == original.worldFrame,
                  actual.motion.pose.translation == original.motion.pose.translation,sameRotation,
                  actual.motion.velocity == original.motion.velocity,
                  actual.prescribedDriftVelocity == original.prescribedDriftVelocity else { throw .staleSource }
            try numerical { () throws(NumericalError) in try work.chargeOperations(24) }
        }
    }
}
