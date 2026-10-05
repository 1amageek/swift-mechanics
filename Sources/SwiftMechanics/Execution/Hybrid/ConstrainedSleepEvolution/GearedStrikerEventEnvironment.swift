@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class GearedStrikerEventEnvironment: ConstrainedSleepEventEnvironment, Sendable {
    public let catalog:HybridEventCatalog
    public let program:StationaryIslandProgram
    public let impactPolicy:ConstrainedImpactPolicy
    public let evolutionPolicy:HybridEvolutionPolicy
    private let first:CollisionProxy
    private let second:CollisionProxy
    private let firstMount:RigidTransform
    private let secondMount:RigidTransform
    private let law:ContactLawPair
    private let queryPolicy:CollisionQueryPolicy
    private let queries:any CollisionGeometryQuerying
    public let gearIslandID:UInt64
    public let strikerIslandID:UInt64
    private let gearIndices:[Int]
    private let strikerIndex:Int
    public init(program:StationaryIslandProgram,first:CollisionProxy,second:CollisionProxy,firstColliderToBody:RigidTransform,secondColliderToBody:RigidTransform,
                law:ContactLawPair,eventID:UInt64,geometryRevision:UInt64,queryPolicy:CollisionQueryPolicy,evolutionPolicy:HybridEvolutionPolicy,impactPolicy:ConstrainedImpactPolicy,
                queries:any CollisionGeometryQuerying = AnalyticCollisionQueries()) throws(HybridError) {
        let model=program.source
        // FIXME(INCOMPLETE_IMPLEMENTATION): Coverage is proved only for one zero-drive direct fixed-root gear island and one row-free scalar prismatic striker with analytic spheres. General loads, moving gear coverage and multiple contact charts require their real coverage producer.
        guard eventID>0,program.drive.allSatisfy({$0 == 0}),program.islands.count == 2,
              program.constraints.rows.allSatisfy({$0.timeLinear == 0 && $0.timeQuadratic == 0 && $0.mixedTime.allSatisfy({$0 == 0}) && $0.hessian.allSatisfy({$0 == 0})}),
              let joint=model.tree.joints.first(where:{$0.childBody == second.geometry.bodyID}),joint.parentBody == model.descriptor.root,joint.manifold.kind == .prismatic,
              let range=model.tree.layout.joints.first(where:{$0.joint == joint.id}),range.positions.count == 1,range.velocities.count == 1,
              let striker=program.islands.first(where:{$0.sourceCoordinateIndices == [range.velocities.start] && $0.retainedRowIDs.isEmpty}),
              let gear=program.islands.first(where:{$0.id != striker.id && !$0.retainedRowIDs.isEmpty && $0.model.tree.bodies.contains(where:{$0.id == first.geometry.bodyID})}),
              first.geometry.bodyID != second.geometry.bodyID,first.geometry.frameID == model.tree.worldFrame,second.geometry.frameID == model.tree.worldFrame,
              first.geometry.frameRevision == model.stamp.revision,second.geometry.frameRevision == model.stamp.revision,
              first.filter.enabled,second.filter.enabled,!first.filter.isTrigger,!second.filter.isTrigger,
              first.filter.layerBits & second.filter.maskBits != 0,second.filter.layerBits & first.filter.maskBits != 0,
              first.geometry.colliderID != second.geometry.colliderID else { throw .unsupportedDomain }
        var signature=ConstrainedSleepSignature(maximum:evolutionPolicy.maximumContinuationBytes,identifierMaximum:impactPolicy.impact.maximumIdentifierBytes)
        try signature.text("constrained-sleep-geared-striker-v1");try signature.word(UInt64(program.binding.count));try signature.raw(program.binding)
        try signature.proxy(first,mount:firstColliderToBody);try signature.proxy(second,mount:secondColliderToBody);try signature.law(law)
        try signature.word(eventID);try signature.word(geometryRevision);try signature.word(gear.id);try signature.word(striker.id)
        for value in [queryPolicy.lengthTolerance,queryPolicy.normalTolerance,queryPolicy.maximumApproximationError] { try signature.scalar(value) }
        try signature.impact(impactPolicy);try signature.evolution(evolutionPolicy)
        catalog=try HybridEventCatalog(model:model.stamp,geometryRevision:geometryRevision,eventIDs:[eventID],providerSignature:signature.bytes,policy:evolutionPolicy)
        self.program=program;self.first=first;self.second=second;firstMount=firstColliderToBody;secondMount=secondColliderToBody;self.law=law;self.queryPolicy=queryPolicy
        self.evolutionPolicy=evolutionPolicy;self.impactPolicy=impactPolicy;self.queries=queries;gearIslandID=gear.id;strikerIslandID=striker.id;gearIndices=gear.sourceCoordinateIndices;strikerIndex=range.velocities.start
    }
    @inline(never)
    public func brackets(from source:RuntimeCheckpoint,through time:Double,work:inout CollisionWork,cancellation:HybridCancellation) throws(HybridError) -> [HybridEventBracket] {
        try cancellation.check()
        guard source.model == catalog.model,time.isFinite,time > source.physical.time,time <= program.constraints.maximumTime,
              source.physical.q.count == program.drive.count,source.physical.v.count == program.drive.count,source.physical.acceleration.count == program.drive.count,
              gearIndices.allSatisfy({source.physical.v[$0] == 0 && source.physical.acceleration[$0] == 0}),source.physical.acceleration[strikerIndex] == 0 else { throw .unsupportedDomain }
        let endPosition=source.physical.q[strikerIndex]+(time-source.physical.time)*source.physical.v[strikerIndex]
        guard endPosition.isFinite,endPosition >= program.constraints.minimumPosition[strikerIndex],endPosition <= program.constraints.maximumPosition[strikerIndex] else { throw .invalidInput }
        let value=try witness(physical:source.physical,work:&work,cancellation:cancellation)
        // FIXME(INCOMPLETE_IMPLEMENTATION): Initial touching/penetrating/support and noncollinear crossing coverage have no selected policy. They must be refused before successful root/evolution publication.
        guard value.witness.separation > impactPolicy.impact.lengthTolerance else { throw .unsupportedDomain }
        let motion=try bodyMotion(source.physical,body:second.geometry.bodyID)
        let r=value.second.pose.translation,p=value.first.pose.translation,v=motion.velocity.linear
        let dx=r.x-p.x,dy=r.y-p.y,dz=r.z-p.z,dist=(dx*dx+dy*dy+dz*dz).squareRoot(),speed=(v.x*v.x+v.y*v.y+v.z*v.z).squareRoot()
        let cross=((dy*v.z-dz*v.y)*(dy*v.z-dz*v.y)+(dz*v.x-dx*v.z)*(dz*v.x-dx*v.z)+(dx*v.y-dy*v.x)*(dx*v.y-dy*v.x)).squareRoot()
        guard dist.isFinite,speed.isFinite,cross.isFinite,motion.velocity.angular == .zero,cross <= impactPolicy.impact.normalTolerance*max(1,dist*speed) else { throw .unsupportedDomain }
        if speed <= impactPolicy.impact.speedTolerance || value.speed >= 0 { return [] }
        guard value.speed < -impactPolicy.impact.speedTolerance else { throw .grazing }
        let hit=source.physical.time+value.witness.separation/(-value.speed)
        let extra=max(2*evolutionPolicy.timeTolerance,2*impactPolicy.impact.lengthTolerance/(-value.speed))
        let upper=min(time,hit+extra)
        guard hit.isFinite,extra.isFinite,upper > source.physical.time,upper < source.physical.time+dist/speed else { throw .noDirectedBracket }
        return [try HybridEventBracket(eventID:catalog.eventIDs[0],lowerTime:source.physical.time,upperTime:upper)]
    }
    @inline(never)
    public func sample(eventID:UInt64,endpoint:IslandSleepTrajectoryEndpoint,work:inout CollisionWork,cancellation:HybridCancellation) throws(HybridError) -> HybridEventSample {
        guard catalog.eventIDs == [eventID],endpoint.source.model == catalog.model else { throw .staleModel }
        let value=try witness(physical:endpoint.physical,work:&work,cancellation:cancellation)
        return try HybridEventSample(gap:value.witness.separation,separatingSpeed:value.speed)
    }
    @inline(never)
    public func impactInput(endpoint:IslandSleepTrajectoryEndpoint,eventIDs:[UInt64],work:inout CollisionWork,cancellation:HybridCancellation) throws(HybridError) -> HardImpactInput {
        guard eventIDs == catalog.eventIDs,endpoint.source.model == catalog.model else { throw .staleModel }
        return try assembleInput(endpoint:endpoint,value:witness(physical:endpoint.physical,work:&work,cancellation:cancellation))
    }
    @inline(never)
    private func assembleInput(endpoint:IslandSleepTrajectoryEndpoint,value:GearedStrikerWitness) throws(HybridError) -> HardImpactInput {
        let model=program.source,compiled:CompiledKinematicState
        do throws(CompilationFailure) { compiled=try model.makeState(endpoint.physical) } catch { throw .compiler(error) }
        var inertias:[RigidBodyInertia]=[];inertias.reserveCapacity(model.tree.bodies.count)
        for body in model.tree.bodies {
            guard let item=model.descriptor.bodies.first(where:{$0.id == body.id}),case .spatial(let record)=item,let inertia=record.inertia else { throw .unsupportedDomain }
            do throws(DynamicsError) { inertias.append(try RigidBodyInertia(body:record.id,frame:record.frame,properties:inertia.properties)) } catch { throw .dynamics(error) }
        }
        let collision:CollisionSnapshot
        do throws(CollisionError) { collision=try CollisionSnapshot(proxies:[value.first,value.second],revision:catalog.geometryRevision) } catch { throw .collision(error) }
        return HardImpactInput(model:model,physical:compiled,inertias:inertias,collision:collision,expectedCollisionRevision:catalog.geometryRevision,
            contacts:[ImpulseContactBinding(eventID:catalog.eventIDs[0],witness:value.witness,firstProxyIndex:0,secondProxyIndex:1,firstColliderToBody:firstMount,secondColliderToBody:secondMount,law:law)])
    }
    @inline(never)
    private func bodyMotion(_ physical:KinematicState,body:EntityID) throws(HybridError) -> FrameMotion {
        let snapshot:KinematicSnapshot
        do throws(CompilationFailure) { snapshot=try program.source.evaluate(program.source.makeState(physical)) } catch { throw .compiler(error) }
        do throws(JointError) { return try snapshot.body(body).motion } catch { throw .joints(error) }
    }
    @inline(never)
    private func witness(physical:KinematicState,work:inout CollisionWork,cancellation:HybridCancellation) throws(HybridError) -> GearedStrikerWitness {
        try cancellation.check()
        do throws(CollisionError) {
            let capacity=program.source.policy.kinematicCapacity
            let storage=try CollisionWork.sum(256,try CollisionWork.sum(try CollisionWork.product(2,capacity.maximumJacobianScalars),try CollisionWork.sum(try CollisionWork.product(64,capacity.maximumBodies),try CollisionWork.product(12,capacity.maximumVelocities))))
            try work.requireStorage(storage);try work.requireRecords(3);try work.charge(storage)
        } catch { throw .collision(error) }
        let aMotion=try bodyMotion(physical,body:first.geometry.bodyID),bMotion=try bodyMotion(physical,body:second.geometry.bodyID)
        let a:CollisionProxy,b:CollisionProxy
        do throws(CoreError) { a=first.moved(to:try aMotion.pose.composed(with:firstMount));b=second.moved(to:try bMotion.pose.composed(with:secondMount)) } catch { throw .core(error) }
        let witness:CollisionWitness
        do throws(CollisionError) { witness=try queries.witness(first:a,second:b,policy:queryPolicy,work:&work) } catch { throw .collision(error) }
        let n=witness.normal
        let speed=(bMotion.velocity.linear.x-aMotion.velocity.linear.x)*n.x+(bMotion.velocity.linear.y-aMotion.velocity.linear.y)*n.y+(bMotion.velocity.linear.z-aMotion.velocity.linear.z)*n.z
        guard aMotion.velocity == FrameMotion.zeroMotion,bMotion.velocity.angular == .zero,speed.isFinite,witness.degeneracy == .regular else { throw .unsupportedDomain }
        return GearedStrikerWitness(witness:witness,first:a,second:b,speed:speed)
    }
}
