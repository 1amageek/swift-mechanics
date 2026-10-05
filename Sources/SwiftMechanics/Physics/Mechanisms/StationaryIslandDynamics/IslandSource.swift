internal enum IslandSource {
    static func inertias(_ model: CompiledMechanicalModel) throws(StationaryIslandFailureReason) -> [RigidBodyInertia] {
        var result:[RigidBodyInertia]=[];result.reserveCapacity(model.tree.bodies.count)
        for body in model.tree.bodies {
            guard let record=model.descriptor.bodies.first(where:{$0.id == body.id}),case .spatial(let spatial)=record,let inertia=spatial.inertia else { throw .unsupportedDomain }
            do throws(DynamicsError) { result.append(try RigidBodyInertia(body:body.id,frame:body.frame,properties:inertia.properties)) }
            catch { throw .dynamics(error) }
        };return result
    }
    static func reserved(_ program: StationaryIslandProgram) throws(StationaryIslandFailureReason) -> Int {
        let n=program.source.tree.layout.velocityCount
        return try IslandArithmetic.sum(try IslandArithmetic.sum(program.binding.count/8,1),
            try IslandArithmetic.sum(try IslandArithmetic.product(256,program.source.tree.bodies.count+program.islands.count),
                try IslandArithmetic.product(try IslandArithmetic.sum(program.constraints.rows.count,8),try IslandArithmetic.product(n,n))))
    }
    static func admit(_ program: StationaryIslandProgram, _ physical: KinematicState, work: inout NumericalWork) throws(StationaryIslandFailureReason) {
        try IslandArithmetic.check(program.policy)
        let n=program.source.tree.layout.velocityCount
        guard physical.revision == program.source.stamp.revision,physical.q.count == n,physical.v.count == n,
              physical.acceleration.count == n,physical.prescribedAnchors.isEmpty,
              physical.time >= program.constraints.minimumTime,physical.time <= program.constraints.maximumTime else { throw .sourceMismatch }
        try IslandArithmetic.storage(try reserved(program),&work);try IslandArithmetic.charge(try IslandArithmetic.product(5,n),&work)
        for i in 0..<n {
            guard physical.q[i].isFinite,physical.v[i].isFinite,physical.acceleration[i].isFinite,
                  physical.q[i] >= program.constraints.minimumPosition[i],physical.q[i] <= program.constraints.maximumPosition[i] else { throw .sourceMismatch }
        }
    }
    @inline(never)
    static func input(model: CompiledMechanicalModel, physical: KinematicState, inertias: [RigidBodyInertia]) throws(StationaryIslandFailureReason) -> RigidDynamicsInput {
        let snapshot:KinematicSnapshot
        do throws(CompilationFailure) { snapshot=try model.evaluate(model.makeState(physical)) } catch { throw .compilation(error) }
        do throws(DynamicsError) { return try RigidDynamicsInput(snapshot:snapshot,velocity:physical.v,inertias:inertias,gravity:nil) }
        catch { throw .dynamics(error) }
    }
    static func physical(_ source: KinematicState, island: StationaryMechanicalIsland) throws(StationaryIslandFailureReason) -> KinematicState {
        do throws(JointError) { return try KinematicState(revision:source.revision,time:source.time,q:island.sourceCoordinateIndices.map {source.q[$0]},
            v:island.sourceCoordinateIndices.map {source.v[$0]},acceleration:island.sourceCoordinateIndices.map {source.acceleration[$0]}) }
        catch { throw .kinematics(error) }
    }
    @inline(never)
    static func assemble(_ input: RigidDynamicsInput, program: StationaryIslandProgram, equations: any RigidEquationComputing,
                         reserved: Int, work: inout StationaryIslandWork) throws(StationaryIslandFailureReason) -> RigidDynamicsSystem {
        let budget=try IslandArithmetic.numerical { () throws(NumericalError) in try work.numerical.remainingBudget(reservedStorage:reserved) }
        var local=StationaryIslandWork(numerical:NumericalWork(budget:budget),loads:work.loads)
        let value:RigidDynamicsSystem
        do throws(StationaryIslandFailureReason) {
            value=try IslandInvocation.assembly(&local) { (loads:inout LoadWork,numerical:inout NumericalWork) throws(StationaryIslandFailureReason) in
                do throws(DynamicsError) { return try equations.assemble(input,admission:program.policy.admission,loadWork:&loads,work:&numerical) }
                catch { throw .dynamics(error) }
            }
        } catch {
            work.loads=local.loads;if local.failedSupplierWorkUnavailable { work.unavailable() }
            try IslandArithmetic.numerical { () throws(NumericalError) in try work.numerical.absorb(local.numerical,reservedStorage:reserved) };throw error
        }
        work.loads=local.loads
        try IslandArithmetic.numerical { () throws(NumericalError) in try work.numerical.absorb(local.numerical,reservedStorage:reserved) }
        try association(value,input:input,work:&work.numerical)
        return value
    }
    static func association(_ value: RigidDynamicsSystem,input: RigidDynamicsInput,work: inout NumericalWork) throws(StationaryIslandFailureReason) {
        let n=input.velocity.count
        try IslandArithmetic.charge(try IslandArithmetic.product(8,n),&work)
        guard value.velocityCount == n,value.massMatrix.count == n*n,value.inertialBias.count == n,
              value.input.snapshot.tree.layout == input.snapshot.tree.layout,value.input.snapshot.tree.revision == input.snapshot.tree.revision,
              value.input.snapshot.time.bitPattern == input.snapshot.time.bitPattern,value.input.snapshot.bodies == input.snapshot.bodies,
              value.input.snapshot.frames == input.snapshot.frames,value.input.snapshot.joints == input.snapshot.joints,
              value.input.snapshot.coordinateRate == input.snapshot.coordinateRate,
              value.input.velocity == input.velocity,value.input.inertias == input.inertias,
              value.input.gravity == nil,value.input.bodyWrenches.isEmpty,value.input.generalizedForces.isEmpty else { throw .sourceMismatch }
        for body in input.snapshot.bodies {
            do throws(JointError) {
                guard try value.input.snapshot.geometricColumns(body:body.body) == input.snapshot.geometricColumns(body:body.body) else { throw JointError.invalidPolicy }
            } catch { throw .kinematics(error) }
        }
        for i in 0..<n {
            do throws(DynamicsError) { guard try value.forces.total(at:i) == 0 else { throw DynamicsError.unsupportedDomain } }
            catch { throw .dynamics(error) }
            guard value.inertialBias[i].isFinite else { throw .residualRejected }
        }
        for v in value.massMatrix { guard v.isFinite else { throw .residualRejected } }
    }
    @inline(never)
    static func validatePartition(_ program: StationaryIslandProgram,physical: KinematicState,equations: any RigidEquationComputing,
                                  work: inout StationaryIslandWork) throws(StationaryIslandFailureReason) {
        try admit(program,physical,work:&work.numerical)
        let reserved=try reserved(program)
        let whole=try assemble(input(model:program.source,physical:physical,inertias:program.inertias),program:program,equations:equations,reserved:reserved,work:&work)
        var membership=[Int](repeating:-1,count:whole.velocityCount)
        for island in program.islands {
            let local=try assemble(input(model:island.model,physical:try self.physical(physical,island:island),inertias:island.inertias),
                program:program,equations:equations,reserved:try IslandArithmetic.sum(reserved,whole.scalarStorage),work:&work)
            let indices=island.sourceCoordinateIndices,ln=indices.count,n=whole.velocityCount
            for i in indices.indices {
                let original=indices[i];guard membership[original] == -1 else { throw .sourceMismatch };membership[original]=Int(island.id)
                guard local.inertialBias[i] == whole.inertialBias[original] else { throw .sourceMismatch }
                for j in indices.indices {
                    try IslandArithmetic.charge(2,&work.numerical)
                    guard local.massMatrix[i*ln+j] == whole.massMatrix[original*n+indices[j]] else { throw .sourceMismatch }
                }
            }
            for body in local.input.snapshot.bodies {
                guard let original=whole.input.snapshot.bodies.first(where:{$0.body == body.body}),body == original else { throw .sourceMismatch }
            }
            // Public slices retain their original immutable snapshot backing during comparison.
            for body in local.input.snapshot.bodies {
                do throws(JointError) {
                    let column=try local.input.snapshot.geometricColumns(body:body.body)
                    let original=try whole.input.snapshot.geometricColumns(body:body.body)
                    for i in indices.indices {
                        guard column[column.startIndex+i] == original[original.startIndex+indices[i]] else { throw JointError.invalidPolicy }
                    }
                } catch { throw .kinematics(error) }
            }
        }
        guard !membership.contains(-1) else { throw .sourceMismatch }
        for i in membership.indices { for j in membership.indices where membership[i] != membership[j] {
            try IslandArithmetic.charge(1,&work.numerical)
            guard whole.massMatrix[i*membership.count+j] == 0 else { throw .sourceMismatch }
        } }
    }
}
