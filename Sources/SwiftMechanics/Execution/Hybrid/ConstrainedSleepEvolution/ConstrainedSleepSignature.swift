internal struct ConstrainedSleepSignature {
    private(set) var bytes:[UInt8]=[]
    let maximum:Int
    let identifierMaximum:Int
    mutating func word(_ value:UInt64) throws(HybridError) {
        guard bytes.count <= maximum,maximum-bytes.count >= 8 else { throw .capacityExceeded };ConstrainedSleepBytes.put(value,into:&bytes)
    }
    mutating func scalar(_ value:Double) throws(HybridError) { guard value.isFinite else { throw .nonFinite };try word(value.bitPattern) }
    mutating func text(_ value:String) throws(HybridError) {
        guard value.utf8.count <= identifierMaximum,bytes.count <= maximum,maximum-bytes.count >= 8,value.utf8.count <= maximum-bytes.count-8 else { throw .capacityExceeded };try word(UInt64(value.utf8.count));try raw(Array(value.utf8))
    }
    mutating func raw(_ value:[UInt8]) throws(HybridError) { guard value.count <= maximum-bytes.count else { throw .capacityExceeded };bytes.append(contentsOf:value) }
    mutating func pose(_ p:RigidTransform) throws(HybridError) { for v in [p.translation.x,p.translation.y,p.translation.z,p.rotation.w,p.rotation.x,p.rotation.y,p.rotation.z] { try scalar(v) } }
    mutating func capability(_ p:LinearCapability) throws(HybridError) {
        try word(p.precision == .float32 ? 0 : 1);try word(p.backend == .referenceCPU ? 0 : 1)
        switch p.algorithm { case .partialPivotLU:try word(0);case .cholesky:try word(1);case .conjugateGradient:try word(2);case .treeElimination:try word(3) }
    }
    mutating func tolerance(_ p:LinearTolerance<Double>) throws(HybridError) { for v in [p.absoluteResidual,p.relativeResidual,p.pivotThreshold] { try scalar(v) } }
    mutating func impact(_ p:ConstrainedImpactPolicy) throws(HybridError) {
        let h=p.impact
        for n in [h.maximumContacts,h.maximumColliders,h.maximumBodies,h.maximumVelocities,h.maximumIdentifierBytes,p.maximumFactorEntries] { try word(UInt64(n)) }
        for v in [h.lengthTolerance,h.normalTolerance,h.speedTolerance,h.independenceTolerance,h.momentumAbsolute,h.momentumRelative,h.energyAbsolute,h.energyRelative,p.minimumEffectiveInverseMass] { try scalar(v) }
        try word(UInt64(h.impulseScales.count));for v in h.impulseScales { try scalar(v) }
        let d=p.dynamics;try capability(d.capability);try tolerance(d.linearTolerance);try word(UInt64(d.coordinateScales.count));for v in d.coordinateScales { try scalar(v) };try scalar(d.energyScale);try scalar(d.timeScale)
        let c=p.constraints
        try word(UInt64(c.diagonalMetric.count));for v in c.diagonalMetric { try scalar(v) }
        for v in [c.energyScale,c.rankRelativeTolerance,c.originalResidualTolerance,c.maximumCorrection] { try scalar(v) }
        try word(c.rankPolicy == .allowRedundancy ? 0 : 1);try word(UInt64(c.evaluation.maximumCoordinates));try word(UInt64(c.evaluation.maximumRows));try word(c.evaluation.expectedLayoutRevision);try capability(c.linearCapability);try tolerance(c.linearTolerance)
        let n=c.nonlinear;try capability(n.capability);try tolerance(n.tolerance)
        switch n.strategy { case .newton:try word(0);case .lineSearch(let a,let b,let c):try word(1);for v in [a,b,c] { try scalar(v) };case .trustRegion(let a,let b,let c,let d,let e,let f,let g,let h):try word(2);for v in [a,b,c,d,e,f,g,h] { try scalar(v) } }
        for v in [n.referenceScale,n.minimumDirectionNorm,n.derivativeProbeDistance,n.derivativeAbsoluteTolerance,n.derivativeRelativeTolerance] { try scalar(v) };try word(UInt64(n.maximumFactorEntries));try word(n.estimateCondition ? 1 : 0)
        for v in [n.budget.scalarStorage,n.budget.arithmeticOperations,n.budget.iterations] { try word(UInt64(v)) }
    }
    mutating func evolution(_ p:HybridEvolutionPolicy) throws(HybridError) {
        for v in [p.maximumEvents,p.maximumQueries,p.maximumRootIterations,p.maximumCatalogEvents,p.maximumContinuationBytes] { try word(UInt64(v)) };try scalar(p.timeTolerance);try scalar(p.minimumEventSpacing)
    }
    mutating func proxy(_ p:CollisionProxy,mount:RigidTransform) throws(HybridError) {
        let g=p.geometry
        for s in [g.colliderID.key,g.bodyID.key,g.frameID.key,g.representation.assetKey,g.representation.provenance.source] { try text(s) }
        for v in [g.geometryRevision,g.frameRevision,g.representation.provenance.revision,p.filter.layerBits,p.filter.maskBits] { try word(v) }
        try word(p.filter.enabled ? 1 : 0);try word(p.filter.isTrigger ? 1 : 0)
        guard case .sphere(let radius)=g.shape,g.resolution == .analytic,g.approximationError == 0 else { throw .unsupportedDomain }
        try scalar(radius);try scalar(g.margin);try pose(mount);try pose(p.pose)
    }
    mutating func law(_ p:ContactLawPair) throws(HybridError) {
        for m in [p.firstMaterial,p.secondMaterial] { try text(m.id.key);try word(m.revision) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): The selected rigid normal domain binds a real linear, frictionless, cohesionless separate impact law. General compliant/frictional and calibrated law coverage requires its own producer before this path succeeds.
        guard case .linear(let k,let d,let x,let v)=p.parameters.normal,case .separateImpact(let e,let t)=p.lossPolicy,p.parameters.friction == .none,p.parameters.cohesion == .none,p.provenance == .symmetricSeriesAndMinima,p.parameters.resistance.rollingCoefficient == 0,p.parameters.resistance.spinningCoefficient == 0 else { throw .unsupportedDomain }
        for value in [k,d,x,v,e,t,p.parameters.resistanceRadius,p.parameters.resistance.rollingCoefficient,p.parameters.resistance.spinningCoefficient,p.parameters.resistance.angularRegularization] { try scalar(value) }
    }
}
