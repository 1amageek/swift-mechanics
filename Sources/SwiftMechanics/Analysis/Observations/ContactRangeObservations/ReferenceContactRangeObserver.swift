/// Injected successful samples must be exactly reference-equivalent at the complete original source.
public struct ReferenceContactRangeObserver: ContactRangeObserving {
    private let geometry:any CollisionGeometryQuerying
    private let discovery:any CollisionDiscovering
    private let persistence:any CollisionPersisting
    private let current:any ContactCurrentEvaluating
    private let kinematics:any KinematicObserving
    public init(geometry:any CollisionGeometryQuerying = AnalyticCollisionQueries(),
                discovery:any CollisionDiscovering = ExhaustiveCollisionDiscovery(),
                persistence:any CollisionPersisting = ValueCollisionPersistence(),
                current:any ContactCurrentEvaluating = CompliantContactCurrentEvaluator(),
                kinematics:any KinematicObserving = ReferenceKinematicObserver()) {
        self.geometry=geometry;self.discovery=discovery;self.persistence=persistence;self.current=current;self.kinematics=kinematics
    }
    @inline(never)
    public func range(scene:ContactRangeScene,mount:ObservationMount,ray:CollisionRay,targets:[EntityID],
                      policy:ContactRangeObservationPolicy,collisionWork:inout CollisionWork,work:inout NumericalWork)
        throws(ContactRangeObservationError) -> RangeObservation {
        try ContactRangeArithmetic.scene(scene,policy,&work)
        let request=try rangeRequest(scene:scene,mount:mount,ray:ray,targets:targets,policy:policy,work:&work)
        let hits=try rangeQuery(request,policy:policy,collisionWork:&collisionWork,work:&work)
        try ContactRangeArithmetic.check(policy)
        return RangeObservation(admission:_RangeObservationAdmission(scene:scene,mount:mount,motion:request.motion,
            ray:request.ray,targets:targets,hits:hits))
    }
    @inline(never)
    public func triggers(scene:ContactRangeScene,mount:ObservationMount,filters:CollisionFilterPolicy,
                         previous:TriggerObservation?,sampleIndex:UInt64,policy:ContactRangeObservationPolicy,
                         collisionWork:inout CollisionWork,work:inout NumericalWork)
        throws(ContactRangeObservationError) -> TriggerObservation {
        try ContactRangeArithmetic.scene(scene,policy,&work)
        try Self.filters(filters,policy:policy,work:&work)
        if let previous {
            try Self.filters(previous.filters,policy:policy,work:&work)
            try ContactRangeEvidence.previous(previous,scene:scene,mount:mount,filters:filters,policy:policy,work:&work)
        }
        let motion=try ContactRangeArithmetic.mounted(kinematics,scene:scene,mount:mount,policy:policy,work:&work)
        let update=try triggerQuery(scene:scene,filters:filters,previous:previous,sampleIndex:sampleIndex,
            policy:policy,collisionWork:&collisionWork,work:&work)
        let geometry=try triggerWitnesses(scene:scene,update:update,previous:previous,policy:policy,collisionWork:&collisionWork,work:&work)
        try ContactRangeArithmetic.check(policy)
        return TriggerObservation(admission:_TriggerObservationAdmission(scene:scene,mount:mount,motion:motion,
            update:update,witnesses:geometry.active,exited:geometry.exited,filters:filters))
    }
    @inline(never)
    public func tactile(scene:ContactRangeScene,mount:ObservationMount,contact:TactileContactBinding,
                        policy:ContactRangeObservationPolicy,collisionWork:inout CollisionWork,
                        contactWork:inout ContactWork,work:inout NumericalWork)
        throws(ContactRangeObservationError) -> TactileObservation {
        try ContactRangeArithmetic.scene(scene,policy,&work)
        let motion=try ContactRangeArithmetic.mounted(kinematics,scene:scene,mount:mount,policy:policy,work:&work)
        let physical=try ContactRangeTactileKinematics.prepare(scene:scene,mount:mount,contact:contact,geometry:geometry,
            policy:policy,collisionWork:&collisionWork,work:&work)
        let response=try currentQuery(physical:physical,contact:contact,policy:policy,contactWork:&contactWork,work:&work)
        let shifted=try Self.shift(physical:physical,motion:motion,response:response,work:&work)
        try ContactRangeArithmetic.check(policy)
        return TactileObservation(admission:_TactileObservationAdmission(scene:scene,mount:mount,motion:motion,
            witness:physical.witness,point:physical.point,basis:physical.basis,relative:physical.relative,angular:physical.angular,
            response:response,side:physical.side,force:shifted.0,couple:shifted.1))
    }
    private final class RangeRequest:Sendable {
        let motion:MountedMotionObservation
        let ray:CollisionRay
        let selected:CollisionSnapshot
        init(motion:MountedMotionObservation,ray:CollisionRay,selected:CollisionSnapshot) { self.motion=motion;self.ray=ray;self.selected=selected }
    }
    @inline(never)
    private func rangeRequest(scene:ContactRangeScene,mount:ObservationMount,ray:CollisionRay,targets:[EntityID],
                              policy:ContactRangeObservationPolicy,work:inout NumericalWork)
        throws(ContactRangeObservationError) -> RangeRequest {
        guard targets.count <= policy.maximumColliders else { throw .capacityExceeded }
        try ContactRangeArithmetic.slots(targets.count,256,&work)
        var selected:[CollisionProxy]=[];selected.reserveCapacity(targets.count)
        for (index,id) in targets.enumerated() {
            try ContactRangeArithmetic.metadata([id.key],policy,&work)
            guard id.kind == .collider else { throw .invalidInput }
            for earlier in targets[..<index] { try ContactRangeArithmetic.charge(1,&work);guard earlier != id else { throw .invalidInput } }
            try ContactRangeArithmetic.charge(scene.colliders.count,&work)
            guard let proxy=scene.collision.proxies.first(where:{$0.geometry.colliderID == id}) else { throw .staleSource }
            selected.append(proxy)
        }
        let motion=try ContactRangeArithmetic.mounted(kinematics,scene:scene,mount:mount,policy:policy,work:&work)
        try ContactRangeArithmetic.charge(256,&work)
        let origin=try ContactRangeArithmetic.core { () throws(CoreError) in try motion.sensorToWorld.transforming(point:ray.origin) }
        let direction=try ContactRangeArithmetic.core { () throws(CoreError) in try motion.sensorToWorld.transforming(direction:ray.direction) }
        try ContactRangeArithmetic.numerical { () throws(NumericalError) in try work.chargeOperations(NumericalWork.product(targets.count,targets.count)) }
        do throws(CollisionError) {
            return RangeRequest(motion:motion,ray:try CollisionRay(origin:origin,direction:direction,maximumDistance:ray.maximumDistance),
                selected:try CollisionSnapshot(proxies:selected,revision:scene.revision))
        } catch { throw .collision(error) }
    }
    @inline(never)
    private func rangeQuery(_ request:RangeRequest,policy:ContactRangeObservationPolicy,collisionWork:inout CollisionWork,
                            work:inout NumericalWork) throws(ContactRangeObservationError) -> [CollisionRayHit] {
        let supplied=try ContactRangeArithmetic.collision(&collisionWork) { (ledger:inout CollisionWork) throws(CollisionError) in
            try discovery.rayHits(snapshot:request.selected,ray:request.ray,policy:policy.query,work:&ledger)
        }
        try ContactRangeArithmetic.check(policy)
        guard supplied.count <= policy.maximumHits else { throw .capacityExceeded }
        let original=try ContactRangeArithmetic.collision(&collisionWork) { (ledger:inout CollisionWork) throws(CollisionError) in
            try ExhaustiveCollisionDiscovery().rayHits(snapshot:request.selected,ray:request.ray,policy:policy.query,work:&ledger)
        }
        try ContactRangeEvidence.hits(supplied,original,policy:policy,work:&work)
        return original
    }
    private static func filters(_ filters:CollisionFilterPolicy,policy:ContactRangeObservationPolicy,work:inout NumericalWork) throws(ContactRangeObservationError) {
        // FIXME(INCOMPLETE_IMPLEMENTATION): Stateful user-filter observation semantics are not admitted.
        // This trigger observer requires declared deterministic filters until callback continuation/source evidence is qualified.
        guard filters.user == nil else { throw .unsupportedSensorModel }
        guard filters.jointExclusions.count <= policy.maximumTriggerRecords else { throw .capacityExceeded }
        try ContactRangeArithmetic.slots(filters.jointExclusions.count,32,&work)
        for pair in filters.jointExclusions { try ContactRangeArithmetic.metadata([pair.first.key,pair.second.key],policy,&work) }
    }
    @inline(never)
    private func triggerQuery(scene:ContactRangeScene,filters:CollisionFilterPolicy,previous:TriggerObservation?,sampleIndex:UInt64,
                              policy:ContactRangeObservationPolicy,collisionWork:inout CollisionWork,work:inout NumericalWork)
        throws(ContactRangeObservationError) -> CollisionTriggerUpdate {
        let supplied=try ContactRangeArithmetic.collision(&collisionWork) { (ledger:inout CollisionWork) throws(CollisionError) in
            try persistence.triggers(snapshot:scene.collision,filters:filters,previous:previous?.update.state,sampleIndex:sampleIndex,policy:policy.query,work:&ledger)
        }
        try ContactRangeArithmetic.check(policy)
        guard supplied.state.intersections.count <= policy.maximumTriggerRecords,supplied.events.count <= policy.maximumTriggerRecords else { throw .capacityExceeded }
        let original=try ContactRangeArithmetic.collision(&collisionWork) { (ledger:inout CollisionWork) throws(CollisionError) in
            try ValueCollisionPersistence().triggers(snapshot:scene.collision,filters:filters,previous:previous?.update.state,sampleIndex:sampleIndex,policy:policy.query,work:&ledger)
        }
        try ContactRangeEvidence.trigger(supplied,original,policy:policy,work:&work);return original
    }
    private final class TriggerGeometry:Sendable {
        let active:[CollisionWitness]
        let exited:[CollisionWitness]
        init(active:[CollisionWitness],exited:[CollisionWitness]) { self.active=active;self.exited=exited }
    }
    @inline(never)
    private func triggerWitnesses(scene:ContactRangeScene,update:CollisionTriggerUpdate,previous:TriggerObservation?,
                                  policy:ContactRangeObservationPolicy,collisionWork:inout CollisionWork,work:inout NumericalWork)
        throws(ContactRangeObservationError) -> TriggerGeometry {
        try ContactRangeArithmetic.slots(update.state.intersections.count,512,&work)
        try ContactRangeArithmetic.slots(update.events.count,512,&work)
        var active:[CollisionWitness]=[],exited:[CollisionWitness]=[]
        active.reserveCapacity(update.state.intersections.count);exited.reserveCapacity(update.events.count)
        for pair in update.state.intersections {
            try ContactRangeArithmetic.charge(scene.colliders.count,&work)
            guard let a=scene.collision.proxies.first(where:{$0.geometry == pair.first}),
                  let b=scene.collision.proxies.first(where:{$0.geometry == pair.second}) else { throw .invalidSupplierEvidence }
            let supplied=try ContactRangeArithmetic.collision(&collisionWork) { (ledger:inout CollisionWork) throws(CollisionError) in
                try geometry.witness(first:a,second:b,policy:policy.query,work:&ledger)
            }
            try ContactRangeArithmetic.check(policy)
            let original=try ContactRangeArithmetic.collision(&collisionWork) { (ledger:inout CollisionWork) throws(CollisionError) in
                try AnalyticCollisionQueries().witness(first:a,second:b,policy:policy.query,work:&ledger)
            }
            try ContactRangeEvidence.witness(supplied,original,policy:policy,work:&work)
            guard original.separation <= 0 else { throw .invalidSupplierEvidence };active.append(original)
        }
        for event in update.events where event.phase == .exited {
            guard let previous else { throw .invalidSupplierEvidence }
            try ContactRangeArithmetic.charge(previous.witnesses.count,&work)
            guard let witness=previous.witnesses.first(where:{$0.pair == event.pair}) else { throw .invalidSupplierEvidence }
            exited.append(witness)
        }
        return TriggerGeometry(active:active,exited:exited)
    }
    @inline(never)
    private func currentQuery(physical:ContactRangeTactileKinematics,contact:TactileContactBinding,
                              policy:ContactRangeObservationPolicy,contactWork:inout ContactWork,work:inout NumericalWork)
        throws(ContactRangeObservationError) -> ContactCurrentResponse {
        let supplied=try ContactRangeArithmetic.current(&contactWork) { (ledger:inout ContactWork) throws(ContactCurrentError) in
            try current.sample(input:physical.input,pair:contact.pair,accepted:contact.accepted,policy:policy.contact,work:&ledger)
        }
        try ContactRangeArithmetic.check(policy)
        let original=try ContactRangeArithmetic.current(&contactWork) { (ledger:inout ContactWork) throws(ContactCurrentError) in
            try CompliantContactCurrentEvaluator().sample(input:physical.input,pair:contact.pair,accepted:contact.accepted,policy:policy.contact,work:&ledger)
        }
        try ContactRangeEvidence.current(supplied,original,policy:policy,work:&work);return original
    }
    @inline(never)
    private static func shift(physical:ContactRangeTactileKinematics,motion:MountedMotionObservation,response:ContactCurrentResponse,
                              work:inout NumericalWork) throws(ContactRangeObservationError) -> (Vector3,Vector3) {
        try ContactRangeArithmetic.charge(256,&work)
        return try ContactRangeArithmetic.core { () throws(CoreError) in
            let sign=physical.side == .second ? 1.0 : -1.0
            let force=try response.forceOnB.scaled(by:sign),couple=try response.coupleOnB.scaled(by:sign)
            let shifted=try couple.adding(physical.point.subtracting(motion.sensorToWorld.translation).cross(force))
            let inverse=motion.sensorToWorld.rotation.conjugated()
            return (try inverse.rotating(force),try inverse.rotating(shifted))
        }
    }
}

internal struct _RangeObservationAdmission:Sendable {
    let scene:ContactRangeScene;let mount:ObservationMount;let motion:MountedMotionObservation
    let ray:CollisionRay;let targets:[EntityID];let hits:[CollisionRayHit]
    fileprivate init(scene:ContactRangeScene,mount:ObservationMount,motion:MountedMotionObservation,ray:CollisionRay,targets:[EntityID],hits:[CollisionRayHit]) {
        self.scene=scene;self.mount=mount;self.motion=motion;self.ray=ray;self.targets=targets;self.hits=hits
    }
}
internal struct _TriggerObservationAdmission:Sendable {
    let scene:ContactRangeScene;let mount:ObservationMount;let motion:MountedMotionObservation
    let update:CollisionTriggerUpdate;let witnesses:[CollisionWitness];let exited:[CollisionWitness];let filters:CollisionFilterPolicy
    fileprivate init(scene:ContactRangeScene,mount:ObservationMount,motion:MountedMotionObservation,update:CollisionTriggerUpdate,
                     witnesses:[CollisionWitness],exited:[CollisionWitness],filters:CollisionFilterPolicy) {
        self.scene=scene;self.mount=mount;self.motion=motion;self.update=update;self.witnesses=witnesses;self.exited=exited;self.filters=filters
    }
}
internal struct _TactileObservationAdmission:Sendable {
    let scene:ContactRangeScene;let mount:ObservationMount;let motion:MountedMotionObservation
    let witness:CollisionWitness;let point:Vector3;let basis:ContactBasis;let relative:Vector3;let angular:Vector3
    let response:ContactCurrentResponse;let side:TactileObservation.Side;let force:Vector3;let couple:Vector3
    fileprivate init(scene:ContactRangeScene,mount:ObservationMount,motion:MountedMotionObservation,witness:CollisionWitness,
                     point:Vector3,basis:ContactBasis,relative:Vector3,angular:Vector3,response:ContactCurrentResponse,
                     side:TactileObservation.Side,force:Vector3,couple:Vector3) {
        self.scene=scene;self.mount=mount;self.motion=motion;self.witness=witness;self.point=point;self.basis=basis
        self.relative=relative;self.angular=angular;self.response=response;self.side=side;self.force=force;self.couple=couple
    }
}
