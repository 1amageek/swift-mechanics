public struct ReferenceContactRangeScenePreparer: ContactRangeScenePreparing {
    public init() {}
    @inline(never)
    public func prepare(model: CompiledMechanicalModel, state: CompiledKinematicState,
                        colliders: [ObservationColliderBinding], revision: UInt64,
                        policy: ContactRangeObservationPolicy, work: inout NumericalWork)
        throws(ContactRangeObservationError) -> ContactRangeScene {
        try ContactRangeArithmetic.check(policy)
        guard colliders.count <= policy.maximumColliders else { throw .capacityExceeded }
        try ContactRangeArithmetic.slots(colliders.count,256,&work)
        try ContactRangeArithmetic.model(model,policy,&work)
        for recipe in colliders { try ContactRangeArithmetic.recipe(recipe,policy,&work) }
        let source=try Self.source(model:model,state:state,policy:policy,work:&work)
        let collision=try Self.placements(source:source,colliders:colliders,revision:revision,policy:policy,work:&work)
        try ContactRangeArithmetic.check(policy)
        return ContactRangeScene(admission:_ContactRangeSceneAdmission(source:source,colliders:colliders,collision:collision,revision:revision))
    }
    @inline(never)
    private static func source(model: CompiledMechanicalModel,state: CompiledKinematicState,
                               policy: ContactRangeObservationPolicy,work: inout NumericalWork)
        throws(ContactRangeObservationError) -> ObservationSource {
        try ContactRangeArithmetic.charge(1,&work)
        let service:any ObservationSourcePreparing=ReferenceObservationSourcePreparer()
        do throws(ObservationError) { return try service.prepare(model:model,state:state,solved:nil,policy:policy.observation,work:&work) }
        catch { throw .observation(error) }
    }
    @inline(never)
    private static func placements(source: ObservationSource,colliders: [ObservationColliderBinding],revision: UInt64,
                                   policy: ContactRangeObservationPolicy,work: inout NumericalWork)
        throws(ContactRangeObservationError) -> CollisionSnapshot {
        var proxies:[CollisionProxy]=[];proxies.reserveCapacity(colliders.count)
        for (index,recipe) in colliders.enumerated() {
            try ContactRangeArithmetic.check(policy);try ContactRangeArithmetic.charge(256,&work)
            for previous in colliders[..<index] { try ContactRangeArithmetic.charge(1,&work);guard previous.colliderID != recipe.colliderID else { throw .invalidInput } }
            guard let body=source.snapshot.bodies.first(where:{$0.body == recipe.body}),
                  let record=source.model.descriptor.bodies.first(where:{$0.id == recipe.body}) else { throw .staleSource }
            guard record.representations.collisionGeometry == recipe.representations.collisionGeometry else { throw .staleSource }
            let pose=try ContactRangeArithmetic.core { () throws(CoreError) in try body.motion.pose.composed(with:recipe.colliderToBody) }
            do throws(CollisionError) {
                let proxy=try CollisionProxy(colliderID:recipe.colliderID,bodyID:recipe.body,frameID:source.snapshot.tree.worldFrame,
                    geometryRevision:recipe.geometryRevision,frameRevision:source.snapshot.tree.revision,shape:recipe.shape,margin:recipe.margin,
                    representations:recipe.representations,expectedSourceRevision:recipe.expectedSourceRevision,resolution:recipe.resolution,
                    pose:pose,filter:recipe.filter)
                try policy.query.validate(proxy);proxies.append(proxy)
            } catch { throw .collision(error) }
        }
        try ContactRangeArithmetic.numerical { () throws(NumericalError) in try work.chargeOperations(NumericalWork.product(colliders.count,colliders.count)) }
        do throws(CollisionError) { return try CollisionSnapshot(proxies:proxies,revision:revision) } catch { throw .collision(error) }
    }
}

internal struct _ContactRangeSceneAdmission: Sendable {
    let source:ObservationSource
    let colliders:[ObservationColliderBinding]
    let collision:CollisionSnapshot
    let revision:UInt64
    fileprivate init(source:ObservationSource,colliders:[ObservationColliderBinding],collision:CollisionSnapshot,revision:UInt64) {
        self.source=source;self.colliders=colliders;self.collision=collision;self.revision=revision
    }
}
