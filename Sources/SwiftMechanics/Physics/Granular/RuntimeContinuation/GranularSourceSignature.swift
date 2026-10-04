internal struct GranularSourceSignature {
    private var bytes: [UInt8] = []
    private let maximum: Int
    private var remaining: Int
    private init(maximum: Int, metadata: Int) { self.maximum=maximum;remaining=metadata }
    @inline(never)
    static func make(initial: GranularState,carrier: ModelStamp,policy: GranularPolicy,step: Double,choices: [Vector3],
                     steps: Int,id: String,maximum: Int,metadata: Int,budget: GranularRuntimePhysicsBudget,
                     work: inout GranularRuntimeWork) throws(GranularRuntimeError) -> [UInt8] {
        var writer=Self(maximum:maximum,metadata:metadata)
        try writer.word(0x314c4e52474d5353,&work);try writer.word(1,&work)
        try writer.text(id,&work);try writer.text(carrier.identity,&work);try writer.word(carrier.revision,&work)
        try writer.word(initial.model.revision,&work);try writer.reference(initial.model.frame,&work)
        for value in [initial.timeSeconds.bitPattern,initial.steps,initial.random.seed,initial.random.state,initial.random.draws,UInt64(steps),UInt64(initial.model.particles.count),UInt64(initial.model.boundaries.count),UInt64(initial.model.bindings.count),UInt64(choices.count)] { try writer.word(value,&work) }
        try writer.scalar(step,&work);for choice in choices { try writer.vector(choice,&work) }
        try writer.originalPolicy(policy,&work)
        for count in [budget.numerical.scalarStorage,budget.numerical.arithmeticOperations,budget.numerical.iterations,
                      budget.collision.scalarStorage,budget.collision.operations,budget.collision.iterations,budget.collision.records,
                      budget.contact.scalarStorage,budget.contact.operations,budget.contact.records,budget.maximumSupplierCalls] { try writer.word(UInt64(count),&work) }
        for (i,particle) in initial.model.particles.enumerated() {
            try writer.proxy(particle.proxy,&work);try writer.reference(particle.body,&work);try writer.reference(particle.material,&work)
            for value in [particle.mass,particle.radius,particle.momentOfInertia] { try writer.scalar(value,&work) }
            let motion=initial.motions[i]
            try writer.vector(motion.position,&work);try writer.vector(motion.velocity,&work);try writer.vector(motion.angularVelocity,&work)
        }
        for boundary in initial.model.boundaries {
            try writer.proxy(boundary.proxy,&work);try writer.reference(boundary.body,&work);try writer.reference(boundary.material,&work)
            try writer.vector(boundary.velocityAtOrigin,&work);try writer.vector(boundary.angularVelocity,&work)
        }
        for binding in initial.model.bindings {
            try writer.word(UInt64(binding.firstParticle),&work)
            try writer.word(binding.secondParticle.map { UInt64($0) } ?? UInt64.max,&work)
            try writer.word(binding.boundary.map { UInt64($0) } ?? UInt64.max,&work)
            let identity=binding.identity
            // FIXME(INCOMPLETE_IMPLEMENTATION): Material-site granular history is not issued by the selected public preparation recipe; it needs an original evolution and source signature contract before journal success.
            guard identity.firstMaterialSite == nil,identity.secondMaterialSite == nil else { throw .unsupportedDomain }
            try writer.text(identity.key,&work);try writer.reference(identity.firstBody,&work)
            try writer.reference(identity.secondBody,&work);try writer.reference(identity.frame,&work)
            for value in [identity.firstGeometryRevision,identity.secondGeometryRevision,identity.tangentLayoutRevision] { try writer.word(value,&work) }
            try writer.law(binding.law,&work)
        }
        try work.poll();return writer.bytes
    }
    private mutating func word(_ value: UInt64,_ work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        try GranularJournalWire.word(value,bytes:&bytes,maximum:maximum,work:&work)
    }
    private mutating func scalar(_ value: Double,_ work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        guard value.isFinite else { throw .invalidInput };try word(value.bitPattern,&work)
    }
    private mutating func text(_ value: String,_ work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        try GranularJournalWire.text(value,bytes:&bytes,maximum:maximum,remaining:&remaining,work:&work)
    }
    private mutating func entity(_ value: EntityID,_ work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        let kind: UInt64
        switch value.kind {
        case .body: kind=0;case .frame: kind=1;case .joint: kind=2;case .collider: kind=3
        case .material: kind=4;case .load: kind=5;case .actuator: kind=6;case .sensor: kind=7
        }
        try word(kind,&work);try text(value.key,&work)
    }
    private mutating func reference(_ value: ModelReference,_ work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        try entity(value.id,&work);try word(value.revision,&work)
    }
    private mutating func vector(_ value: Vector3,_ work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        for scalar in [value.x,value.y,value.z] { try self.scalar(scalar,&work) }
    }
    private mutating func proxy(_ proxy: CollisionProxy,_ work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        let geometry=proxy.geometry
        try entity(geometry.colliderID,&work);try entity(geometry.bodyID,&work);try entity(geometry.frameID,&work)
        try word(geometry.geometryRevision,&work);try word(geometry.frameRevision,&work)
        // FIXME(INCOMPLETE_IMPLEMENTATION): Journal source construction admits only the original granular sphere/plane domain. Other geometry needs its own original evolution/replay proof before successful continuation.
        switch geometry.shape { case .sphere(let radius): try word(0,&work);try scalar(radius,&work)
        case .halfSpace: try word(1,&work)
        default: throw .unsupportedDomain }
        try scalar(geometry.margin,&work)
        guard geometry.representation.kind == .collisionGeometry,geometry.resolution == .analytic else { throw .unsupportedDomain }
        try text(geometry.representation.assetKey,&work);try text(geometry.representation.provenance.source,&work)
        try word(geometry.representation.provenance.revision,&work)
        switch geometry.representation.quality { case .exact: try word(0,&work)
        case .approximation(let error): try word(1,&work);try scalar(error,&work) }
        let rotation=proxy.pose.rotation
        for value in [rotation.w,rotation.x,rotation.y,rotation.z] { try scalar(value,&work) }
        try vector(proxy.pose.translation,&work)
        for value in [proxy.filter.enabled ? UInt64(1) : 0,proxy.filter.isTrigger ? UInt64(1) : 0,proxy.filter.layerBits,proxy.filter.maskBits] { try word(value,&work) }
    }
    private mutating func law(_ pair: ContactLawPair,_ work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        try reference(pair.firstMaterial,&work);try reference(pair.secondMaterial,&work)
        switch pair.provenance { case .symmetricSeriesAndMinima: try word(0,&work)
        case .orderedCalibratedOverride(let revision): try word(1,&work);try word(revision,&work) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Separate impact cannot be replayed by compliant granular evolution. Journal continuation must refuse until an identified impact/evolution composition is supplied.
        guard pair.lossPolicy == .compliantDampingOnly else { throw .unsupportedDomain }
        let p=pair.parameters
        switch p.normal {
        case .linear(let k,let d,let penetration,let speed): try word(0,&work);for v in [k,d,penetration,speed] { try scalar(v,&work) }
        case .hertz(let k,let r,let penetration,let speed): try word(1,&work);for v in [k,r,penetration,speed] { try scalar(v,&work) }
        case .huntCrossley(let k,let a,let r,let penetration,let speed): try word(2,&work);for v in [k,a,r,penetration,speed] { try scalar(v,&work) }
        }
        switch p.friction { case .none: try word(0,&work)
        case .elasticCoulomb(let f): try word(1,&work);for v in [f.staticFirst,f.staticSecond,f.dynamicFirst,f.dynamicSecond,f.tangentialStiffness,f.transitionSpeed] { try scalar(v,&work) } }
        for v in [p.resistance.rollingCoefficient,p.resistance.spinningCoefficient,p.resistance.angularRegularization,p.resistanceRadius] { try scalar(v,&work) }
        switch p.cohesion { case .none: try word(0,&work)
        case .reversibleLinear(let limit,let range): try word(1,&work);try scalar(limit,&work);try scalar(range,&work) }
    }
    private mutating func originalPolicy(_ p: GranularPolicy,_ work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        for count in [p.maximumParticles,p.maximumBoundaries,p.maximumContacts,p.maximumNeighbors] { try word(UInt64(count),&work) }
        for v in [p.momentumTolerance,p.angularMomentumTolerance,p.energyTolerance,p.referenceMomentum,p.referenceAngularMomentum,p.referenceEnergy,
                  p.relativeTolerance,p.minimumTransportDot,p.collision.lengthTolerance,p.collision.normalTolerance,p.collision.maximumApproximationError,
                  p.contact.absoluteEnergyTolerance,p.contact.absolutePowerTolerance,p.contact.relativeTolerance,p.contact.coneTolerance,p.contact.referenceEnergy,p.contact.referencePower] { try scalar(v,&work) }
    }
}
