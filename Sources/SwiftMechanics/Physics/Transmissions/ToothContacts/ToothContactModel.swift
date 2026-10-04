public final class ToothContactModel: Sendable {
    public let source: SourceProvenance
    public let tree: KinematicTree
    public let referenceCoordinates: [Double]
    public let inertias: [RigidBodyInertia]
    public let teeth: [ToothProxyBinding]
    public let contacts: [ToothContactPair]
    public let driveForce: [Double]
    public let jointPolicy: JointEvaluationPolicy
    public let identifierBytes: Int
    public init(source: SourceProvenance, tree: KinematicTree, referenceCoordinates: [Double], inertias: [RigidBodyInertia],
                teeth: [ToothProxyBinding], contacts: [ToothContactPair], driveForce: [Double], jointPolicy: JointEvaluationPolicy,
                policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) {
        try ToothArithmetic.check(policy)
        guard teeth.count <= policy.maximumTeeth, contacts.count <= policy.maximumContacts else { throw .capacityExceeded }
        // FIXME(INCOMPLETE_IMPLEMENTATION): General shaft trees, moving/floating roots and planar inertia are unsupported.
        // This ToothContacts admission rejects them until original chart/inertia/source evolution and independent evidence exist.
        guard tree.rootBase == .fixed, tree.bodies.count == 3, tree.joints.count == 2,
              tree.layout.positionCount == 2, tree.layout.velocityCount == 2, tree.bodies.allSatisfy({ $0.dimension == .spatial }),
              referenceCoordinates.count == 2, inertias.count == 3, driveForce.count == 2,
              !teeth.isEmpty, !contacts.isEmpty else { throw .unsupportedDomain }
        try work.charge(1024,storage:ToothArithmetic.slots(teeth:teeth.count,contacts:contacts.count))
        var remaining=policy.maximumIdentifierBytes
        try ToothArithmetic.key(source.source,remaining:&remaining,policy:policy,work:&work)
        try ToothArithmetic.key(tree.worldFrame.key,remaining:&remaining,policy:policy,work:&work)
        for body in tree.bodies {
            try ToothArithmetic.key(body.id.key,remaining:&remaining,policy:policy,work:&work)
            try ToothArithmetic.key(body.frame.key,remaining:&remaining,policy:policy,work:&work)
        }
        for joint in tree.joints {
            try ToothArithmetic.key(joint.id.key,remaining:&remaining,policy:policy,work:&work)
            for anchor in [joint.parentAnchor,joint.childAnchor] {
                try ToothArithmetic.key(anchor.frame.key,remaining:&remaining,policy:policy,work:&work)
                guard case .fixed=anchor.placement else { throw .unsupportedDomain }
            }
            guard joint.parentBody == tree.bodies[0].id, joint.manifold.kind == .revolute else { throw .unsupportedDomain }
        }
        for tooth in teeth {
            try ToothArithmetic.key(tooth.proxy.geometry.colliderID.key,remaining:&remaining,policy:policy,work:&work)
            try ToothArithmetic.key(tooth.proxy.geometry.bodyID.key,remaining:&remaining,policy:policy,work:&work)
            try ToothArithmetic.key(tooth.proxy.geometry.frameID.key,remaining:&remaining,policy:policy,work:&work)
            try ToothArithmetic.key(tooth.proxy.geometry.representation.assetKey,remaining:&remaining,policy:policy,work:&work)
            try ToothArithmetic.key(tooth.proxy.geometry.representation.provenance.source,remaining:&remaining,policy:policy,work:&work)
        }
        for pair in contacts {
            try ToothArithmetic.key(pair.key,remaining:&remaining,policy:policy,work:&work)
            try ToothArithmetic.key(pair.law.firstMaterial.id.key,remaining:&remaining,policy:policy,work:&work)
            try ToothArithmetic.key(pair.law.secondMaterial.id.key,remaining:&remaining,policy:policy,work:&work)
        }
        for value in referenceCoordinates+driveForce { try ToothArithmetic.finite(value) }
        self.source=source; self.tree=tree; self.referenceCoordinates=referenceCoordinates; self.inertias=inertias
        self.teeth=teeth; self.contacts=contacts; self.driveForce=driveForce; self.jointPolicy=jointPolicy
        identifierBytes=policy.maximumIdentifierBytes-remaining
        try validate(policy:policy,work:&work)
        let state: KinematicState
        do { state=try KinematicState(revision:tree.revision,time:0,q:referenceCoordinates,v:[0,0],acceleration:[0,0]) } catch { throw .joint(error) }
        let snapshot=try ToothArithmetic.snapshot(self,state:state,policy:policy,work:&work)
        for tooth in teeth {
            let body: BodyKinematics
            do { body=try snapshot.body(tooth.proxy.geometry.bodyID) } catch { throw .joint(error) }
            let pose=try ToothArithmetic.core { () throws(CoreError) in try body.motion.pose.composed(with:tooth.colliderToBody) }
            try ToothArithmetic.vector(pose.translation,tooth.proxy.pose.translation,policy:policy)
            let a=try ToothArithmetic.core { () throws(CoreError) in try pose.rotation.matrix() }
            let b=try ToothArithmetic.core { () throws(CoreError) in try tooth.proxy.pose.rotation.matrix() }
            guard a == b else { throw .staleSource }
        }
    }
    internal func validate(policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) {
        try ToothArithmetic.check(policy)
        guard teeth.count <= policy.maximumTeeth, contacts.count <= policy.maximumContacts,
              policy.dynamics.coordinateScales.count == 2 else { throw .capacityExceeded }
        let repeated=try ToothArithmetic.sum(ToothArithmetic.product(teeth.count,teeth.count),ToothArithmetic.product(contacts.count,contacts.count))
        let comparedBytes=try ToothArithmetic.product(ToothArithmetic.product(2,identifierBytes),ToothArithmetic.sum(teeth.count,contacts.count))
        try work.charge(ToothArithmetic.sum(512,ToothArithmetic.sum(ToothArithmetic.product(64,repeated),comparedBytes)),
            storage:ToothArithmetic.slots(teeth:teeth.count,contacts:contacts.count))
        for i in teeth.indices {
            let tooth=teeth[i], geometry=tooth.proxy.geometry
            guard geometry.frameID == tree.worldFrame, geometry.frameRevision == tree.revision,
                  geometry.bodyID == tree.bodies[1].id || geometry.bodyID == tree.bodies[2].id else { throw .staleSource }
            guard tooth.proxy.filter.enabled, !tooth.proxy.filter.isTrigger else { throw .unsupportedDomain }
            do { try policy.collision.validate(tooth.proxy) } catch { throw .collision(error) }
            if case .sampled(let spacing)=geometry.resolution {
                guard spacing <= policy.maximumFeatureSpacingMeters else { throw .capacityExceeded }
            }
            for j in 0..<i {
                guard tooth.proxy.geometry.colliderID != teeth[j].proxy.geometry.colliderID,
                      tooth.toothID != teeth[j].toothID else { throw .invalidInput }
            }
        }
        var firstCount=0, secondCount=0
        for tooth in teeth { if tooth.proxy.geometry.bodyID == tree.bodies[1].id { firstCount += 1 } else { secondCount += 1 } }
        guard firstCount > 0, secondCount > 0, contacts.count == (try ToothArithmetic.product(firstCount,secondCount)) else { throw .invalidInput }
        for i in contacts.indices {
            let pair=contacts[i]
            guard teeth.indices.contains(pair.firstProxy), teeth.indices.contains(pair.secondProxy),
                  teeth[pair.firstProxy].proxy.geometry.bodyID == tree.bodies[1].id,
                  teeth[pair.secondProxy].proxy.geometry.bodyID == tree.bodies[2].id else { throw .invalidInput }
            let a=teeth[pair.firstProxy].proxy, b=teeth[pair.secondProxy].proxy
            guard a.filter.layerBits & b.filter.maskBits != 0, b.filter.layerBits & a.filter.maskBits != 0 else { throw .unsupportedDomain }
            switch (a.geometry.shape,b.geometry.shape) {
            case (.sphere,.sphere),(.sphere,.box),(.box,.sphere): break
            // FIXME(INCOMPLETE_IMPLEMENTATION): Generic tooth mesh/box-box witnesses are unavailable in the frozen producer.
            // ToothContacts rejects such actual catalogs until original collision geometry and refinement proof exist.
            default: throw .unsupportedDomain
            }
            // FIXME(INCOMPLETE_IMPLEMENTATION): Friction, damped/nonlinear normal, cohesive and impact tooth evolution is incomplete.
            // Current selected evolution rejects those laws; original coupled work/history/event evidence is required before success.
            guard case .linear(_,let damping,_,_)=pair.law.parameters.normal, damping == 0,
                  pair.law.parameters.friction == .none, pair.law.parameters.cohesion == .none,
                  pair.law.parameters.resistance.rollingCoefficient == 0, pair.law.parameters.resistance.spinningCoefficient == 0,
                  pair.law.lossPolicy == .compliantDampingOnly else { throw .unsupportedDomain }
            for j in 0..<i { guard pair.key != contacts[j].key,
                pair.firstProxy != contacts[j].firstProxy || pair.secondProxy != contacts[j].secondProxy else { throw .invalidInput } }
        }
    }
    internal func validatePolicy(_ policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) {
        try ToothArithmetic.check(policy)
        guard teeth.count <= policy.maximumTeeth, contacts.count <= policy.maximumContacts, identifierBytes <= policy.maximumIdentifierBytes,
              policy.dynamics.coordinateScales.count == 2 else { throw .capacityExceeded }
        try work.charge(ToothArithmetic.sum(ToothArithmetic.product(16,identifierBytes),ToothArithmetic.product(128,teeth.count)),
            storage:ToothArithmetic.slots(teeth:teeth.count,contacts:contacts.count))
        for tooth in teeth {
            do { try policy.collision.validate(tooth.proxy) } catch { throw .collision(error) }
            if case .sampled(let spacing)=tooth.proxy.geometry.resolution {
                guard spacing <= policy.maximumFeatureSpacingMeters else { throw .capacityExceeded }
            }
        }
    }
    internal func matches(_ other: ToothContactModel) -> Bool {
        source == other.source && tree.bodies == other.tree.bodies && tree.joints == other.tree.joints && tree.rootBase == other.tree.rootBase &&
        tree.worldFrame == other.tree.worldFrame && tree.revision == other.tree.revision && tree.layout == other.tree.layout &&
        referenceCoordinates == other.referenceCoordinates && inertias == other.inertias && teeth == other.teeth && contacts == other.contacts &&
        driveForce == other.driveForce && jointPolicy == other.jointPolicy
    }
}
