/// Accepted continuation for concrete stationary affine dynamics with piecewise constant commands.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class CheckpointedMechanismSleep: MechanismSleepContinuing, Sendable {
    public let model:CompiledMechanicalModel
    public let constraints:QuadraticConstraintSystem
    public let solvePolicy:MechanismSolvePolicy
    public let admission:DynamicsAdmission
    public let policy:MechanismSleepContinuationPolicy
    public let descriptor:ODEDescriptor
    public let continuation:IntegrationContinuationProvider
    public let schema:RuntimeContributorSchema
    public var schemas:[RuntimeContributorSchema] { continuation.schemas+[schema] }
    private let initialDrive:[Double]
    internal let inertias:[RigidBodyInertia]
    private let signature:[UInt8]
    internal let memo=MechanismSleepMemo()

    public init(identity:String,model:CompiledMechanicalModel,constraints:QuadraticConstraintSystem,drive:[Double],
                solvePolicy:MechanismSolvePolicy,admission:DynamicsAdmission,policy:MechanismSleepContinuationPolicy,
                integration:ExplicitIntegrationPolicy) throws(RuntimeFailure) {
        let n=model.tree.layout.velocityCount
        guard n > 0,n <= policy.thresholds.maximumCoordinates,n <= admission.capacity.maximumVelocities,model.tree.bodies.count <= admission.capacity.maximumBodies else { throw RuntimeFailure(.capacityExceeded,message:"Sleep coordinate capacity exceeded.") }
        // FIXME(INCOMPLETE_IMPLEMENTATION): General mechanism sleep callers can reach this constructor. Only concrete stationary affine force provenance is admitted; gravity, external force callbacks, moving constraints and nonlinear/floating charts require their own immutable/versioned producer contracts and behavioral suspension proof before success.
        guard constraints.rows.allSatisfy({$0.timeLinear == 0 && $0.timeQuadratic == 0 && $0.mixedTime.allSatisfy({$0 == 0})}) else {
            throw RuntimeFailure(.unsupportedDomain,message:"Sleep requires stationary affine constraints.")
        }
        let equation:AffineMechanismEquation
        do throws(MechanismError) { equation=try AffineMechanismEquation(identity:identity,model:model,constraints:constraints,drive:drive,
            policy:solvePolicy,admission:admission,maximumIdentityBytes:policy.maximumIdentityBytes) }
        catch { throw RuntimeFailure(.unsupportedDomain,message:"Concrete affine sleep model admission failed.",failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        descriptor=equation.descriptor;continuation=try IntegrationContinuationProvider(descriptor:equation.descriptor,policy:integration)
        self.model=model;self.constraints=constraints;self.solvePolicy=solvePolicy;self.admission=admission;self.policy=policy;initialDrive=drive
        var bound:[RigidBodyInertia]=[]
        for body in model.tree.bodies {
            guard let record=model.descriptor.bodies.first(where:{$0.id == body.id}),case .spatial(let source)=record,let inertia=source.inertia else { throw RuntimeFailure(.unsupportedDomain,message:"Sleep requires explicit actual spatial inertias.") }
            do { bound.append(try RigidBodyInertia(body:source.id,frame:source.frame,properties:inertia.properties)) }
            catch { throw RuntimeFailure(.invalidState,message:"Sleep actual inertia binding failed.") }
        };inertias=bound
        var data=MechanismSleepPayload()
        for value in [descriptor.identity,descriptor.chart,model.stamp.identity] {
            data.put(UInt64(value.utf8.count));data.bytes.append(contentsOf:value.utf8)
        }
        data.put(model.stamp.revision);data.put(policy.thresholds.kineticEnergyThreshold)
        data.put(policy.thresholds.normalizedVelocityThreshold);data.put(policy.minimumRestDuration)
        signature=data.bytes
        let bytes:Int
        do { bytes=try NumericalWork.sum(data.bytes.count,try NumericalWork.product(8,try NumericalWork.sum(6,try NumericalWork.product(6,n)))) }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Sleep contributor byte count overflow.") }
        schema=try RuntimeContributorSchema(id:"mechanics.mechanism.sleep.v1",category:.event,version:1,maximumBytes:bytes)
    }
    public func initialRecord(physical:KinematicState,acceptedSequence:UInt64 = 0) throws(RuntimeFailure) -> RuntimeContributorState {
        let n=model.tree.layout.velocityCount
        guard physical.revision == model.stamp.revision,physical.q.count == n,physical.v.count == n else { throw RuntimeFailure(.incompatibleModel,message:"Sleep initial physical chart differs.") }
        return try record(MechanismSleepHistory(time:physical.time,sequence:acceptedSequence,q:physical.q,v:physical.v,drive:initialDrive,generation:0,
            asleep:[Bool](repeating:false,count:n),restSince:[Double](repeating:physical.time,count:n),wakeSequence:0,kind:0,coordinates:[Bool](repeating:false,count:n)))
    }
    internal func record(_ history:MechanismSleepHistory) throws(RuntimeFailure) -> RuntimeContributorState {
        try valid(history)
        var data=MechanismSleepPayload(bytes:signature);data.bytes.reserveCapacity(schema.maximumBytes)
        data.put(history.acceptedTime);data.put(history.acceptedSequence);data.put(history.commandGeneration)
        data.put(history.wakeSequence);data.put(history.lastWakeKind);data.put(UInt64(model.tree.layout.velocityCount))
        for values in [history.position,history.velocity,history.drive,history.restSince] { for value in values { data.put(value) } }
        for flags in [history.asleep,history.lastWakeCoordinates] { for value in flags { data.put(UInt64(value ? 1 : 0)) } }
        guard data.bytes.count == schema.maximumBytes else { throw RuntimeFailure(.invalidContributor,message:"Sleep writer layout differs.") }
        return try RuntimeContributorState(id:schema.id,category:schema.category,version:schema.version,bytes:data.bytes)
    }
    public func history(_ record:RuntimeContributorState) throws(RuntimeFailure) -> MechanismSleepHistory {
        guard record.id == schema.id,record.category == schema.category,record.version == schema.version,
              record.bytes.count == schema.maximumBytes,record.bytes.starts(with:signature) else { throw RuntimeFailure(.invalidContributor,message:"Sleep contributor schema/signature/size differs.") }
        var data=MechanismSleepPayload(bytes:Array(record.bytes.dropFirst(signature.count)))
        let time=try data.scalar(),sequence=try data.integer(),generation=try data.integer(),wake=try data.integer(),kind=try data.integer()
        let n=model.tree.layout.velocityCount
        guard try data.integer() == UInt64(n) else { throw RuntimeFailure(.invalidContributor,message:"Sleep chart count differs.") }
        var arrays:[[Double]]=[]
        for _ in 0..<4 { var values:[Double]=[];values.reserveCapacity(n);for _ in 0..<n { values.append(try data.scalar()) };arrays.append(values) }
        var flags:[[Bool]]=[]
        for _ in 0..<2 { var values:[Bool]=[];values.reserveCapacity(n);for _ in 0..<n { values.append(try data.flag()) };flags.append(values) }
        guard data.isAtEnd else { throw RuntimeFailure(.invalidContributor,message:"Sleep history has trailing fields.") }
        let value=MechanismSleepHistory(time:time,sequence:sequence,q:arrays[0],v:arrays[1],drive:arrays[2],generation:generation,
            asleep:flags[0],restSince:arrays[3],wakeSequence:wake,kind:kind,coordinates:flags[1]);try valid(value);return value
    }
    private func valid(_ value:MechanismSleepHistory) throws(RuntimeFailure) {
        let n=model.tree.layout.velocityCount
        guard value.acceptedTime.isFinite,value.acceptedTime >= constraints.minimumTime,value.acceptedTime <= constraints.maximumTime,
              [value.position,value.velocity,value.drive,value.restSince].allSatisfy({$0.count == n && $0.allSatisfy({$0.isFinite})}),
              value.asleep.count == n,value.lastWakeCoordinates.count == n,value.restSince.allSatisfy({$0 <= value.acceptedTime}),
              value.lastWakeKind <= 2,value.wakeSequence <= value.acceptedSequence,
              (value.lastWakeKind == 0 ? value.wakeSequence == 0 && !value.lastWakeCoordinates.contains(true) : value.wakeSequence > 0 && value.lastWakeCoordinates.contains(true)),
              (!value.asleep.contains(true) || value.velocity.allSatisfy({$0 == 0})) else {
            throw RuntimeFailure(.invalidContributor,message:"Sleep history physical/time/event fields are invalid.")
        }
        for i in 0..<n {
            guard value.position[i] >= constraints.minimumPosition[i],value.position[i] <= constraints.maximumPosition[i],
                  !value.asleep[i] || value.acceptedTime-value.restSince[i] >= policy.minimumRestDuration else { throw RuntimeFailure(.invalidContributor,message:"Sleep dwell or physical coordinate interval is invalid.") }
        }
    }
    internal func associated(_ record:RuntimeContributorState,physical:KinematicState,sequence:UInt64) throws(RuntimeFailure) -> MechanismSleepHistory {
        let value=try history(record)
        guard physical.revision == model.stamp.revision,value.position == physical.q,value.velocity == physical.v,
              value.acceptedTime == physical.time,value.acceptedSequence == sequence else { throw RuntimeFailure(.invalidContributor,message:"Sleep history differs from complete accepted physical/time/sequence source.") }
        return value
    }
    internal func equation(drive:[Double]) throws(RuntimeFailure) -> AffineMechanismEquation {
        do throws(MechanismError) { return try AffineMechanismEquation(identity:descriptor.identity,model:model,constraints:constraints,drive:drive,
            policy:solvePolicy,admission:admission,maximumIdentityBytes:policy.maximumIdentityBytes) }
        catch { throw RuntimeFailure(.invalidState,message:"Constant-command actual equation construction failed.",failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
    }
    @inline(never)
    public func step(_ session:any RuntimeSessionOperating) throws(MechanismSleepFailure) -> IntegrationAdvanceResult {
        let equation=try prepareStep(session)
        return try integrateStep(session,equation:equation)
    }
    @inline(never)
    private func prepareStep(_ session:any RuntimeSessionOperating) throws(MechanismSleepFailure) -> SleepMechanismEquation {
        let expected=session.snapshot()
        do throws(RuntimeFailure) {
            guard expected.checkpoint.acceptedSteps < UInt64.max else { throw RuntimeFailure(.integerOverflow,message:"Sleep accepted sequence cannot advance.") }
            guard expected.physical.stamp == model.stamp,let record=expected.checkpoint.contributors.first(where:{$0.id == schema.id}) else { throw RuntimeFailure(.missingContributor,message:"Bound mechanism sleep contributor is missing.") }
            let history=try associated(record,physical:expected.checkpoint.physical,sequence:expected.checkpoint.acceptedSteps)
            return try SleepMechanismEquation(owner:self,source:expected,history:history)
        } catch { throw .preflight(error,accepted:expected) }
    }
    @inline(never)
    private func integrateStep(_ session:any RuntimeSessionOperating,equation:SleepMechanismEquation) throws(MechanismSleepFailure) -> IntegrationAdvanceResult {
        do throws(IntegrationFailure) { return try ReferenceExplicitIntegrator().step(session,model:model,equations:equation,continuation:continuation) }
        catch { throw .integration(error) }
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Legacy runtime contributor admission reaches this record-only method. Sleep authority requires the complete checkpoint physical/time/sequence and must fail until contextual validation is selected by the runtime handler.
    public func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        if record.id == continuation.schema.id { return try continuation.validate(record,model:model,budget:budget) }
        throw RuntimeFailure(.unsupportedDomain,message:"Mechanism sleep admission requires complete contextual checkpoint validation.")
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Runtime topology migration reaches this operation. Target static-force/chart authority and connected-component event migration are not produced by current stable contracts; no old sleeping record may be accepted in a new topology until those proofs exist.
    public func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        throw RuntimeFailure(.incompatibleMigration,message:"Mechanism sleep topology migration requires explicit target force/chart/connectivity authority.")
    }
}
