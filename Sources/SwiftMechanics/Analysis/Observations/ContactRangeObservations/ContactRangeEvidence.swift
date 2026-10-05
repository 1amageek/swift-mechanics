internal enum ContactRangeEvidence {
    static func witness(_ supplied:CollisionWitness,_ original:CollisionWitness,policy:ContactRangeObservationPolicy,
                        work:inout NumericalWork) throws(ContactRangeObservationError) {
        try ContactRangeArithmetic.geometry(supplied.pair.first,policy,&work)
        try ContactRangeArithmetic.geometry(supplied.pair.second,policy,&work);try ContactRangeArithmetic.charge(256,&work)
        guard supplied.pair == original.pair,supplied.pointA == original.pointA,supplied.pointB == original.pointB,
              supplied.normal == original.normal,supplied.separation == original.separation,
              supplied.featureA == original.featureA,supplied.featureB == original.featureB,
              supplied.degeneracy == original.degeneracy,supplied.approximationError == original.approximationError,
              supplied.originalBalanceResidual == original.originalBalanceResidual else { throw .invalidSupplierEvidence }
        guard try ContactRangeArithmetic.pose(supplied.poseA,original.poseA) else { throw .invalidSupplierEvidence }
        guard try ContactRangeArithmetic.pose(supplied.poseB,original.poseB) else { throw .invalidSupplierEvidence }
    }
    static func hits(_ supplied:[CollisionRayHit],_ original:[CollisionRayHit],policy:ContactRangeObservationPolicy,
                     work:inout NumericalWork) throws(ContactRangeObservationError) {
        guard supplied.count <= policy.maximumHits,original.count <= policy.maximumHits else { throw .capacityExceeded }
        try ContactRangeArithmetic.slots(supplied.count,128,&work)
        guard supplied.count == original.count else { throw .invalidSupplierEvidence }
        for (a,b) in zip(supplied,original) {
            try ContactRangeArithmetic.check(policy);try ContactRangeArithmetic.geometry(a.geometry,policy,&work)
            try ContactRangeArithmetic.charge(32,&work)
            guard a.geometry == b.geometry,a.distance == b.distance,a.point == b.point,
                  a.outwardNormal == b.outwardNormal,a.feature == b.feature else { throw .invalidSupplierEvidence }
        }
    }
    static func trigger(_ supplied:CollisionTriggerUpdate,_ original:CollisionTriggerUpdate,policy:ContactRangeObservationPolicy,
                        work:inout NumericalWork) throws(ContactRangeObservationError) {
        guard supplied.state.intersections.count <= policy.maximumTriggerRecords,supplied.events.count <= policy.maximumTriggerRecords,
              original.state.intersections.count <= policy.maximumTriggerRecords,original.events.count <= policy.maximumTriggerRecords else { throw .capacityExceeded }
        try ContactRangeArithmetic.slots(supplied.events.count,256,&work)
        try ContactRangeArithmetic.slots(supplied.state.intersections.count,256,&work)
        guard supplied.state.sampleIndex == original.state.sampleIndex,supplied.state.intersections.count == original.state.intersections.count,
              supplied.events.count == original.events.count else { throw .invalidSupplierEvidence }
        for (a,b) in zip(supplied.state.intersections,original.state.intersections) {
            try pair(a,policy:policy,work:&work);guard a == b else { throw .invalidSupplierEvidence }
        }
        for (a,b) in zip(supplied.events,original.events) {
            try pair(a.pair,policy:policy,work:&work)
            guard a.pair == b.pair,a.phase == b.phase,a.sampleIndex == b.sampleIndex else { throw .invalidSupplierEvidence }
        }
    }
    private static func pair(_ value:CollisionPairIdentity,policy:ContactRangeObservationPolicy,work:inout NumericalWork) throws(ContactRangeObservationError) {
        try ContactRangeArithmetic.geometry(value.first,policy,&work);try ContactRangeArithmetic.geometry(value.second,policy,&work)
    }
    @inline(never)
    static func current(_ a:ContactCurrentResponse,_ b:ContactCurrentResponse,policy:ContactRangeObservationPolicy,
                        work:inout NumericalWork) throws(ContactRangeObservationError) {
        try ContactRangeArithmetic.history(a.acceptedHistory,policy,&work)
        try ContactRangeArithmetic.storage(128,&work);try ContactRangeArithmetic.charge(256,&work)
        guard a.acceptedHistory == b.acceptedHistory,a.forceOnB == b.forceOnB,a.coupleOnB == b.coupleOnB else { throw .invalidSupplierEvidence }
        let x=a.derivatives,y=b.derivatives
        let left=[a.compressiveNormalForce,a.elasticNormalForce,a.cohesiveNormalForce,a.tangentialForceFirst,a.tangentialForceSecond,
                  a.normalStoredEnergy,a.tangentialStoredEnergy,a.cohesivePotentialEnergy,a.completeCohesiveSeparationWork,
                  a.normalDissipationPower,a.resistanceDissipationPower,a.relativeMechanicalPower,a.elasticPotentialRatePower,
                  a.staticFrictionConeUtilization,a.originalPowerResidual,a.originalRatePowerResidual,
                  x.normalForcePenetrationDerivative,x.normalForceVelocityDerivative,x.cohesiveForceSeparationDerivative,
                  x.tangentialForceBristleDerivative,x.rollingFirstAngularDerivative,x.rollingCrossAngularDerivative,
                  x.rollingSecondAngularDerivative,x.spinningAngularDerivative]
        let right=[b.compressiveNormalForce,b.elasticNormalForce,b.cohesiveNormalForce,b.tangentialForceFirst,b.tangentialForceSecond,
                  b.normalStoredEnergy,b.tangentialStoredEnergy,b.cohesivePotentialEnergy,b.completeCohesiveSeparationWork,
                  b.normalDissipationPower,b.resistanceDissipationPower,b.relativeMechanicalPower,b.elasticPotentialRatePower,
                  b.staticFrictionConeUtilization,b.originalPowerResidual,b.originalRatePowerResidual,
                  y.normalForcePenetrationDerivative,y.normalForceVelocityDerivative,y.cohesiveForceSeparationDerivative,
                  y.tangentialForceBristleDerivative,y.rollingFirstAngularDerivative,y.rollingCrossAngularDerivative,
                  y.rollingSecondAngularDerivative,y.spinningAngularDerivative]
        guard left == right,x.normalIsDifferentiable == y.normalIsDifferentiable,
              x.cohesionIsDifferentiable == y.cohesionIsDifferentiable,
              x.coupleCompressiveLoadDerivative == y.coupleCompressiveLoadDerivative else { throw .invalidSupplierEvidence }
        try ContactRangeArithmetic.check(policy)
    }
    @inline(never)
    static func previous(_ previous:TriggerObservation,scene:ContactRangeScene,mount:ObservationMount,
                         filters:CollisionFilterPolicy,policy:ContactRangeObservationPolicy,work:inout NumericalWork) throws(ContactRangeObservationError) {
        try ContactRangeArithmetic.scene(previous.scene,policy,&work)
        guard previous.witnesses.count <= policy.maximumTriggerRecords,
              previous.update.state.intersections.count <= policy.maximumTriggerRecords else { throw .capacityExceeded }
        try ContactRangeArithmetic.slots(previous.witnesses.count,256,&work)
        try ContactRangeArithmetic.charge(512,&work)
        let a=previous.scene.source,b=scene.source
        guard a.model.stamp == b.model.stamp,a.model.descriptor == b.model.descriptor,
              a.snapshot.tree.layout == b.snapshot.tree.layout,a.snapshot.tree.bodies == b.snapshot.tree.bodies,
              a.snapshot.tree.joints == b.snapshot.tree.joints,a.snapshot.tree.rootBase == b.snapshot.tree.rootBase,
              a.snapshot.tree.worldFrame == b.snapshot.tree.worldFrame,a.snapshot.tree.revision == b.snapshot.tree.revision,
              previous.scene.revision == scene.revision,previous.scene.colliders == scene.colliders,
              previous.filters.user == nil,previous.filters.allowSameBody == filters.allowSameBody,
              previous.filters.jointExclusions == filters.jointExclusions else { throw .staleSource }
        guard try ContactRangeArithmetic.mount(previous.mount,mount) else { throw .staleSource }
        guard previous.timeSeconds < b.state.state.time else { throw .temporalMismatch }
    }
}
