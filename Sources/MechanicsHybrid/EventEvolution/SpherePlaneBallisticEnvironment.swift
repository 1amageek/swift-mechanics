import MechanicsCore
import MechanicsModel
import MechanicsCompiler
import MechanicsJoints
import MechanicsDynamics
import MechanicsRuntime
import MechanicsIntegration
import MechanicsCollision
import MechanicsContactLaws

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct SpherePlaneBallisticEnvironment: HybridEventEnvironment {
    public let catalog: HybridEventCatalog
    private let model: CompiledMechanicalModel
    private let equation: PrismaticBallisticEquation
    private let sphere: CollisionProxy
    private let plane: CollisionProxy
    private let sphereToBody: RigidTransform
    private let planeToBody: RigidTransform
    private let pair: ContactLawPair
    private let queryPolicy: CollisionQueryPolicy
    private let lengthTolerance: Double
    private let speedTolerance: Double
    private let queries: any CollisionGeometryQuerying
    public init(model: CompiledMechanicalModel, equation: PrismaticBallisticEquation, sphere: CollisionProxy, plane: CollisionProxy,
                sphereToBody: RigidTransform, planeToBody: RigidTransform, law: ContactLawPair, eventID: UInt64, geometryRevision: UInt64,
                queryPolicy: CollisionQueryPolicy, evolutionPolicy: HybridEvolutionPolicy, impactPolicy: HybridPolicy,
                queries: any CollisionGeometryQuerying = AnalyticCollisionQueries()) throws(HybridError) {
        do { try equation.validate(model:model) } catch { throw .runtime(error) }
        guard case .sphere=sphere.geometry.shape, case .halfSpace=plane.geometry.shape,
              sphere.geometry.bodyID == model.tree.bodies[1].id, plane.geometry.bodyID == model.tree.bodies[0].id,
              sphere.geometry.frameID == model.tree.worldFrame, plane.geometry.frameID == model.tree.worldFrame,
              sphere.geometry.frameRevision == model.stamp.revision, plane.geometry.frameRevision == model.stamp.revision,
              plane.pose.rotation == .identity, planeToBody.rotation == .identity,
              sphere.geometry.resolution == .analytic, plane.geometry.resolution == .analytic else { throw .unsupportedDomain }
        guard sphere.geometry.approximationError == 0, plane.geometry.approximationError == 0,
              law.parameters.friction == .none, law.parameters.cohesion == .none,
              law.parameters.resistance.rollingCoefficient == 0, law.parameters.resistance.spinningCoefficient == 0 else { throw .unsupportedDomain }
        let texts=[equation.descriptor.identity,sphere.geometry.colliderID.key,plane.geometry.colliderID.key,
                   sphere.geometry.bodyID.key,plane.geometry.bodyID.key,sphere.geometry.frameID.key,plane.geometry.frameID.key,
                   sphere.geometry.representation.assetKey,plane.geometry.representation.assetKey,
                   sphere.geometry.representation.provenance.source,plane.geometry.representation.provenance.source,
                   law.firstMaterial.id.key,law.secondMaterial.id.key]
        let preflight: (total: Int, identityBytes: Int, recordBytes: Int)
        var providerBounds: HybridByteBounds
        var textLengths: [Int]=[]
        do throws(RuntimeFailure) {
            preflight=try HybridByteBounds.recordCapacity(identity:model.stamp.identity,providerBytes:0,events:1,
                q:model.tree.layout.positionCount,v:model.tree.layout.velocityCount,scales:impactPolicy.impulseScales.count,maximum:evolutionPolicy.maximumContinuationBytes)
            providerBounds=HybridByteBounds(maximum:evolutionPolicy.maximumContinuationBytes-preflight.total)
            // Geometry/frame/provenance/filter/material revisions, two poses, sphere/margins and restitution fields.
            try providerBounds.words(35)
            textLengths.reserveCapacity(texts.count)
            for text in texts { textLengths.append(try providerBounds.text(text,identifierLimit:impactPolicy.maximumIdentifierBytes,prefixed:true)) }
        } catch { throw .runtime(error) }
        var data=HybridPayload(); data.bytes.reserveCapacity(providerBounds.bytes)
        for (text,length) in zip(texts,textLengths) { data.put(UInt64(length)); data.bytes.append(contentsOf:text.utf8) }
        data.put(sphere.geometry.geometryRevision); data.put(plane.geometry.geometryRevision)
        data.put(sphere.geometry.frameRevision); data.put(plane.geometry.frameRevision)
        data.put(sphere.geometry.representation.provenance.revision); data.put(plane.geometry.representation.provenance.revision)
        for proxy in [sphere,plane] { data.put(proxy.filter.layerBits); data.put(proxy.filter.maskBits); data.put(UInt64(proxy.filter.enabled ? 1 : 0)); data.put(UInt64(proxy.filter.isTrigger ? 1 : 0)) }
        data.put(law.firstMaterial.revision); data.put(law.secondMaterial.revision)
        for pose in [sphereToBody,planeToBody] { for value in [pose.translation.x,pose.translation.y,pose.translation.z,pose.rotation.w,pose.rotation.x,pose.rotation.y,pose.rotation.z] { data.put(value) } }
        if case .sphere(let radius)=sphere.geometry.shape { data.put(radius) }; data.put(sphere.geometry.margin); data.put(plane.geometry.margin)
        // Restitution/threshold are continuation physics; compliant normal stiffness is not used as an impact coefficient.
        guard case .separateImpact(let restitution,let threshold)=law.lossPolicy else { throw .unsupportedDomain }
        data.put(restitution); data.put(threshold)
        guard data.bytes.count == providerBounds.bytes else { throw .invalidOwnerAccess }
        catalog=try HybridEventCatalog(model:model.stamp,geometryRevision:geometryRevision,eventIDs:[eventID],providerSignature:data.bytes,policy:evolutionPolicy)
        self.model=model; self.equation=equation; self.sphere=sphere; self.plane=plane
        self.sphereToBody=sphereToBody; self.planeToBody=planeToBody; pair=law; self.queryPolicy=queryPolicy
        lengthTolerance=impactPolicy.lengthTolerance; speedTolerance=impactPolicy.speedTolerance; self.queries=queries
        guard try ImpactArithmetic.samePose(ImpactArithmetic.core { () throws(CoreError) in try model.initialSnapshot.bodies[1].motion.pose.composed(with:sphereToBody) },sphere.pose,policy:impactPolicy),
              try ImpactArithmetic.samePose(ImpactArithmetic.core { () throws(CoreError) in try model.initialSnapshot.bodies[0].motion.pose.composed(with:planeToBody) },plane.pose,policy:impactPolicy) else { throw .stalePose }
    }
    public func brackets(from source: RuntimeCheckpoint, to time: Double, cancellation: HybridCancellation) throws(HybridError) -> [HybridEventBracket] {
        try cancellation.check()
        guard source.model == model.stamp, source.physical.q.count == 1, source.physical.v.count == 1,
              time.isFinite, time > source.physical.time else { throw .invalidInput }
        let snapshot=try evaluate(source)
        let center=try ImpactArithmetic.core { () throws(CoreError) in try snapshot.bodies[1].motion.pose.transforming(point:sphereToBody.translation) }
        let floor=try ImpactArithmetic.core { () throws(CoreError) in try snapshot.bodies[0].motion.pose.transforming(point:planeToBody.translation) }
        guard case .sphere(let radius)=sphere.geometry.shape else { throw .unsupportedDomain }
        let gap=try ImpactArithmetic.finite(center.z-floor.z-radius-sphere.geometry.margin-plane.geometry.margin)
        guard gap >= -lengthTolerance else { throw .invalidWitness }
        let velocity=source.physical.v[0], acceleration=equation.accelerationMetersPerSecondSquared
        var lower=source.physical.time
        if velocity > 0 {
            lower=try ImpactArithmetic.finite(lower-velocity/acceleration)
            if lower >= time { return [] }
        } else if gap <= lengthTolerance {
            // FIXME(INCOMPLETE_IMPLEMENTATION): Resting, initially closing boundary and plastic-stop continuation reach this branch.
            // Continuous support/reaction or explicit initial-impact state policy is required before successful evolution.
            throw .unsupportedDomain
        }
        // Constant downward acceleration gives exactly one monotone closing branch after its apex.
        // Actual reintegration and collision samples determine whether/where this branch crosses; this is not translation CCD.
        return [try HybridEventBracket(eventID:catalog.eventIDs[0],lowerTime:lower,upperTime:time)]
    }
    public func sample(eventID: UInt64, state: RuntimeCheckpoint, work: inout CollisionWork, cancellation: HybridCancellation) throws(HybridError) -> HybridEventSample {
        guard eventID == catalog.eventIDs[0] else { throw .invalidInput }
        let value=try witness(state,work:&work,cancellation:cancellation)
        return try HybridEventSample(gap:value.0.separation,separatingSpeed:state.physical.v[0])
    }
    public func impactInput(state: RuntimeCheckpoint, eventIDs: [UInt64], work: inout CollisionWork, cancellation: HybridCancellation) throws(HybridError) -> HardImpactInput {
        guard eventIDs == catalog.eventIDs else { throw .invalidInput }
        let value=try witness(state,work:&work,cancellation:cancellation)
        let physical: CompiledKinematicState
        do { physical=try model.makeState(state.physical) } catch { throw .compiler(error) }
        var inertias: [RigidBodyInertia]=[]
        for id in model.tree.layout.bodyOrder {
            guard let body=model.descriptor.bodies.first(where: { $0.id == id }), case .spatial(let record)=body,
                  let inertia=record.inertia else { throw .unsupportedDomain }
            do { inertias.append(try RigidBodyInertia(body:record.id,frame:record.frame,properties:inertia.properties)) } catch { throw .dynamics(error) }
        }
        let collision: CollisionSnapshot
        do { collision=try CollisionSnapshot(proxies:[value.1,value.2],revision:catalog.geometryRevision) } catch { throw .collision(error) }
        return HardImpactInput(model:model,physical:physical,inertias:inertias,collision:collision,expectedCollisionRevision:catalog.geometryRevision,
            contacts:[ImpulseContactBinding(eventID:eventIDs[0],witness:value.0,firstProxyIndex:0,secondProxyIndex:1,
                firstColliderToBody:sphereToBody,secondColliderToBody:planeToBody,law:pair)])
    }
    public func postJump(physical: KinematicState, velocity: [Double]) throws(HybridError) -> KinematicState {
        guard velocity.count == 1 else { throw .invalidInput }
        do { return try KinematicState(revision:physical.revision,time:physical.time,q:physical.q,v:velocity,acceleration:[equation.accelerationMetersPerSecondSquared]) }
        catch { throw .joints(error) }
    }
    private func evaluate(_ state: RuntimeCheckpoint) throws(HybridError) -> KinematicSnapshot {
        guard state.model == model.stamp else { throw .staleModel }
        do { return try model.evaluate(model.makeState(state.physical)) } catch { throw .compiler(error) }
    }
    private func witness(_ state: RuntimeCheckpoint, work: inout CollisionWork, cancellation: HybridCancellation) throws(HybridError) -> (CollisionWitness,CollisionProxy,CollisionProxy) {
        try cancellation.check(); let snapshot=try evaluate(state)
        let a=sphere.moved(to:try ImpactArithmetic.core { () throws(CoreError) in try snapshot.bodies[1].motion.pose.composed(with:sphereToBody) })
        let b=plane.moved(to:try ImpactArithmetic.core { () throws(CoreError) in try snapshot.bodies[0].motion.pose.composed(with:planeToBody) })
        do { return (try queries.witness(first:a,second:b,policy:queryPolicy,work:&work),a,b) } catch { throw .collision(error) }
    }
}
