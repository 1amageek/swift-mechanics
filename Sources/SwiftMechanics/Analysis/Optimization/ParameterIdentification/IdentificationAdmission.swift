internal enum IdentificationAdmission {
    static func admit(_ p:PhysicalIdentificationProblem,_ policy:IdentificationPolicy,_ s:inout IdentificationWorkspace,
                      _ c:inout IdentificationContext,_ w:inout NumericalWork) throws(IdentificationCause) {
        try IdentificationArithmetic.check(policy)
        let source=p.source,t=source.tree,n=p.observations.count
        guard n > 0, n <= policy.maximumObservations else { throw .capacity }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Only the fixed-root single-prismatic model is implemented. This estimate entry refuses other trees before any law/solver call; general physical identification needs its own parameter products and original observation proof.
        guard t.rootBase == .fixed, t.bodies.count == 2, t.joints.count == 1,
              t.layout.positionCount == 1, t.layout.velocityCount == 1,
              t.bodies[0].dimension == .spatial, t.bodies[1].dimension == .spatial,
              t.joints[0].manifold.kind == .prismatic else { throw .unsupportedDomain }
        guard case .fixed = t.joints[0].parentAnchor.placement,
              case .fixed = t.joints[0].childAnchor.placement else { throw .unsupportedDomain }
        guard source.referenceInertias.count == 2, p.metadata.variableIDs.count == 2,
              p.metadata.variableReferences.count == 2, p.lowerBounds.count == 2,p.upperBounds.count == 2,
              p.metadata.equalityReferences.isEmpty,p.metadata.inequalityReferences.isEmpty else { throw .invalidSource }
        let retained=try IdentificationArithmetic.sum(try IdentificationArithmetic.sum(s.design.capacity,s.offset.capacity),
            try IdentificationArithmetic.sum(s.physicalResiduals.capacity,try IdentificationArithmetic.sum(s.information.capacity,s.covariance.capacity)))
        c.reserved=try IdentificationArithmetic.sum(retained,try IdentificationArithmetic.sum(512,IdentificationArithmetic.product(n,8)))
        do { try w.requireStorage(c.reserved) } catch { throw .numerical(error) }
        try IdentificationArithmetic.key(p.metadata.identity,policy,&c,&w)
        try IdentificationArithmetic.id(source.body.id,policy,&c,&w)
        try IdentificationArithmetic.id(t.worldFrame,policy,&c,&w)
        for id in [t.joints[0].id,t.joints[0].parentBody,t.joints[0].childBody,t.joints[0].parentAnchor.frame,t.joints[0].childAnchor.frame] {
            try IdentificationArithmetic.id(id,policy,&c,&w)
        }
        for i in 0..<2 {
            try IdentificationArithmetic.id(t.bodies[i].id,policy,&c,&w)
            try IdentificationArithmetic.id(t.bodies[i].frame,policy,&c,&w)
            try IdentificationArithmetic.id(source.referenceInertias[i].body,policy,&c,&w)
            try IdentificationArithmetic.id(source.referenceInertias[i].frame,policy,&c,&w)
            guard source.referenceInertias[i].body == t.bodies[i].id,
                  source.referenceInertias[i].frame == t.bodies[i].frame else { throw .invalidSource }
        }
        try IdentificationArithmetic.charge(20,policy,&w)
        guard source.body.id == t.bodies[1].id, source.body.revision == t.revision,
              p.metadata.provenance.revision == t.revision,source.massParameterID != source.dampingParameterID,
              p.metadata.variableIDs[0] == source.massParameterID,p.metadata.variableIDs[1] == source.dampingParameterID else { throw .invalidSource }
        guard p.metadata.variableReferences[0].dimension == .mass,
              p.metadata.variableReferences[1].dimension == PhysicalDimension(mass:1,time:-1),
              p.metadata.variableReferences[0].magnitude > 0,p.metadata.variableReferences[1].magnitude > 0,
              p.metadata.objectiveReference.dimension == .dimensionless,p.metadata.objectiveReference.magnitude == 1 else { throw .invalidUnits }
        guard source.dashpotRestCoordinate.isFinite,source.maximumDisplacement.isFinite,source.maximumDisplacement > 0,
              source.maximumRate.isFinite,source.maximumRate >= 0 else { throw .invalidSource }
        guard p.lowerBounds[0].isFinite,p.upperBounds[0].isFinite,p.lowerBounds[0] > 0,p.lowerBounds[0] < p.upperBounds[0],
              p.lowerBounds[1].isFinite,p.upperBounds[1].isFinite,p.lowerBounds[1] >= 0,p.lowerBounds[1] < p.upperBounds[1] else { throw .invalidBounds }
        for observation in p.observations {
            try IdentificationArithmetic.charge(8,policy,&w)
            let state=observation.state
            guard state.revision == t.revision,state.q.count == 1,state.v.count == 1,state.acceleration.count == 1,
                  state.prescribedAnchors.isEmpty,observation.appliedForceNewtons.isFinite,
                  observation.forceStandardDeviationNewtons.isFinite,observation.forceStandardDeviationNewtons > 0 else { throw .invalidObservation }
        }
        try IdentificationArithmetic.charge(try IdentificationArithmetic.sum(8,IdentificationArithmetic.product(n,4)),policy,&w)
        s.design=[Double](repeating:0,count:try IdentificationArithmetic.product(n,2))
        s.offset=[Double](repeating:0,count:n);s.physicalResiduals=[Double](repeating:0,count:n)
        s.information=[Double](repeating:0,count:4);s.covariance=[Double](repeating:0,count:4)
    }
}
