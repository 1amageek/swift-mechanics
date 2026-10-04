@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class LoadedCheckpointedMechanismSleep:LoadedMechanismSleepContinuing,Sendable {
    public let model:CompiledMechanicalModel
    public let constraints:QuadraticConstraintSystem
    public let solvePolicy:MechanismSolvePolicy
    public let admission:DynamicsAdmission
    public let policy:MechanismSleepContinuationPolicy
    public let catalog:StationaryLoadCatalog
    public let initialSelection:StationaryLoadSelection
    public let descriptor:ODEDescriptor
    public let continuation:IntegrationContinuationProvider
    public let schema:RuntimeContributorSchema
    public var schemas:[RuntimeContributorSchema] { continuation.schemas+[schema] }
    internal let initialDrive:[Double]
    internal let initialEquation:StationaryAffineMechanismEquation
    internal let memo=LoadedSleepProofStorage()
    private let signature:[UInt8]
    public init(identity:String,model:CompiledMechanicalModel,constraints:QuadraticConstraintSystem,drive:[Double],solvePolicy:MechanismSolvePolicy,admission:DynamicsAdmission,policy:MechanismSleepContinuationPolicy,integration:ExplicitIntegrationPolicy,catalog:StationaryLoadCatalog,initialSelection:StationaryLoadSelection) throws(RuntimeFailure) {
        self.model=model;self.constraints=constraints;self.solvePolicy=solvePolicy;self.admission=admission;self.policy=policy;self.catalog=catalog;self.initialSelection=initialSelection;initialDrive=drive
        guard model.tree.layout.velocityCount <= policy.thresholds.maximumCoordinates,model.tree.layout.velocityCount <= admission.capacity.maximumVelocities,model.tree.bodies.count <= admission.capacity.maximumBodies,initialSelection.generation == 0,
              constraints.rows.allSatisfy({$0.timeLinear == 0 && $0.timeQuadratic == 0 && $0.mixedTime.allSatisfy({$0 == 0})}) else { throw RuntimeFailure(.unsupportedDomain,message:"Loaded sleep requires stationary scalar affine constraints and initial generation zero.") }
        let base:AffineMechanismEquation
        do throws(MechanismError) { base=try AffineMechanismEquation(identity:identity,model:model,constraints:constraints,drive:drive,policy:solvePolicy,admission:admission,maximumIdentityBytes:policy.maximumIdentityBytes) }
        catch { throw RuntimeFailure(.unsupportedDomain,message:"Loaded affine model admission failed.",failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        let empty:StationaryLoadExecution
        do { empty=try StationaryLoadExecution(scope:.equationExecution,budget:LoadBudget(maximumWork:0,maximumScalars:0),maximumInvocations:0,requiredScalars:model.tree.layout.velocityCount) }
        catch { throw RuntimeFailure(.invalidInput,message:"Loaded descriptor accounting context failed.") }
        let equation=try StationaryAffineMechanismEquation(base:base,catalog:catalog,selection:initialSelection,execution:empty,maximumIdentityBytes:policy.maximumIdentityBytes)
        initialEquation=equation;_=empty.close()
        descriptor=equation.descriptor;continuation=try IntegrationContinuationProvider(descriptor:descriptor,policy:integration)
        var data=MechanismSleepPayload()
        data.put(UInt64(descriptor.chart.utf8.count));data.bytes.append(contentsOf:descriptor.chart.utf8)
        data.put(policy.thresholds.kineticEnergyThreshold);data.put(policy.thresholds.normalizedVelocityThreshold);data.put(policy.minimumRestDuration)
        signature=data.bytes
        let bytes:Int
        do { bytes=try NumericalWork.sum(data.bytes.count,try NumericalWork.product(8,try NumericalWork.sum(11,try NumericalWork.product(6,model.tree.layout.velocityCount)))) }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Loaded sleep record size overflow.") }
        schema=try RuntimeContributorSchema(id:"mechanics.mechanism.loaded-sleep.v1",category:.event,version:1,maximumBytes:bytes)
    }
    public func initialRecord(physical:KinematicState,acceptedSequence:UInt64 = 0) throws(RuntimeFailure) -> RuntimeContributorState {
        let n=model.tree.layout.velocityCount
        let mechanics=MechanismSleepHistory(time:physical.time,sequence:acceptedSequence,q:physical.q,v:physical.v,drive:initialDrive,generation:0,asleep:[Bool](repeating:false,count:n),restSince:[Double](repeating:physical.time,count:n),wakeSequence:0,kind:0,coordinates:[Bool](repeating:false,count:n))
        guard physical.revision == model.stamp.revision else { throw RuntimeFailure(.incompatibleModel,message:"Loaded initial physical revision differs.") }
        return try record(LoadedMechanismSleepHistory(mechanics:mechanics,selection:initialSelection,previousProgramID:initialSelection.programID,previousRevision:initialSelection.revision))
    }
    public func initialIntegrationRecord(physical:KinematicState) throws(RuntimeFailure) -> RuntimeContributorState {
        let execution:StationaryLoadExecution
        do { execution=try StationaryLoadExecution(scope:.equationExecution,budget:LoadBudget(maximumWork:0,maximumScalars:0),maximumInvocations:0,requiredScalars:model.tree.layout.velocityCount) }
        catch { throw RuntimeFailure(.invalidInput,message:"Loaded initial chart context failed.") }
        defer { _=execution.close() }
        return try continuation.initialRecord(physical:physical,equations:equation(drive:initialDrive,selection:initialSelection,execution:execution))
    }
    internal func record(_ value:LoadedMechanismSleepHistory) throws(RuntimeFailure) -> RuntimeContributorState {
        try valid(value)
        var data=MechanismSleepPayload(bytes:signature);data.bytes.reserveCapacity(schema.maximumBytes)
        let h=value.mechanics
        data.put(h.acceptedTime)
        for word in [h.acceptedSequence,h.commandGeneration,h.wakeSequence,h.lastWakeKind,UInt64(h.position.count),value.selection.programID,value.selection.revision,value.selection.generation,value.previousProgramID,value.previousRevision] { data.put(word) }
        for array in [h.position,h.velocity,h.drive,h.restSince] { for x in array { data.put(x) } }
        for array in [h.asleep,h.lastWakeCoordinates] { for x in array { data.put(UInt64(x ? 1 : 0)) } }
        guard data.bytes.count == schema.maximumBytes else { throw RuntimeFailure(.invalidContributor,message:"Loaded history byte layout differs.") }
        return try RuntimeContributorState(id:schema.id,category:schema.category,version:schema.version,bytes:data.bytes)
    }
    public func history(_ record:RuntimeContributorState) throws(RuntimeFailure) -> LoadedMechanismSleepHistory {
        guard record.id == schema.id,record.category == schema.category,record.version == schema.version,record.bytes.count == schema.maximumBytes,record.bytes.starts(with:signature) else { throw RuntimeFailure(.invalidContributor,message:"Loaded physical/catalog/policy signature differs.") }
        var data=MechanismSleepPayload(bytes:Array(record.bytes.dropFirst(signature.count)))
        let time=try data.scalar(),sequence=try data.integer(),command=try data.integer(),wake=try data.integer(),kind=try data.integer(),count=try data.integer()
        let selection=StationaryLoadSelection(programID:try data.integer(),revision:try data.integer(),generation:try data.integer())
        let previous=try data.integer(),previousRevision=try data.integer(),n=model.tree.layout.velocityCount
        guard count == UInt64(n) else { throw RuntimeFailure(.invalidContributor,message:"Loaded record chart count differs.") }
        var arrays:[[Double]]=[]
        for _ in 0..<4 { var array:[Double]=[];array.reserveCapacity(n);for _ in 0..<n { array.append(try data.scalar()) };arrays.append(array) }
        var flags:[[Bool]]=[]
        for _ in 0..<2 { var array:[Bool]=[];array.reserveCapacity(n);for _ in 0..<n { array.append(try data.flag()) };flags.append(array) }
        guard data.isAtEnd else { throw RuntimeFailure(.invalidContributor,message:"Loaded history trailing fields.") }
        let h=MechanismSleepHistory(time:time,sequence:sequence,q:arrays[0],v:arrays[1],drive:arrays[2],generation:command,asleep:flags[0],restSince:arrays[3],wakeSequence:wake,kind:kind,coordinates:flags[1])
        let result=LoadedMechanismSleepHistory(mechanics:h,selection:selection,previousProgramID:previous,previousRevision:previousRevision);try valid(result);return result
    }
    private func valid(_ value:LoadedMechanismSleepHistory) throws(RuntimeFailure) {
        let h=value.mechanics,n=model.tree.layout.velocityCount
        do throws(StationaryLoadError) {
            _=try catalog.program(value.selection)
            _=try catalog.program(StationaryLoadSelection(programID:value.previousProgramID,revision:value.previousRevision,generation:0))
        } catch { throw error.runtimeFailure }
        guard h.acceptedTime.isFinite,h.acceptedTime >= constraints.minimumTime,h.acceptedTime <= constraints.maximumTime,
              [h.position,h.velocity,h.drive,h.restSince].allSatisfy({$0.count == n && $0.allSatisfy({$0.isFinite})}),h.asleep.count == n,h.lastWakeCoordinates.count == n,
              h.lastWakeKind <= 3,h.wakeSequence <= h.acceptedSequence,h.restSince.allSatisfy({$0 <= h.acceptedTime}),
              (h.lastWakeKind == 0 ? h.wakeSequence == 0 && !h.lastWakeCoordinates.contains(true) : h.wakeSequence > 0 && h.lastWakeCoordinates.allSatisfy({$0})),
              (!h.asleep.contains(true) || h.velocity.allSatisfy({$0 == 0})),value.selection.generation <= h.acceptedSequence,
              (h.lastWakeKind != 3 || value.selection.generation > 0 && (value.selection.programID != value.previousProgramID || value.selection.revision != value.previousRevision)) else { throw RuntimeFailure(.invalidContributor,message:"Loaded physical/history/event fields are invalid.") }
        if value.selection.generation == 0 {
            guard value.selection == initialSelection,value.previousProgramID == initialSelection.programID,value.previousRevision == initialSelection.revision else { throw RuntimeFailure(.invalidContributor,message:"Generation-zero load authority differs from the admitted initial program.") }
        }
        for i in 0..<n {
            guard h.position[i] >= constraints.minimumPosition[i],h.position[i] <= constraints.maximumPosition[i],!h.asleep[i] || h.acceptedTime-h.restSince[i] >= policy.minimumRestDuration else { throw RuntimeFailure(.invalidContributor,message:"Loaded rest dwell/domain is invalid.") }
        }
    }
    internal func associated(_ record:RuntimeContributorState,physical:KinematicState,sequence:UInt64) throws(RuntimeFailure) -> LoadedMechanismSleepHistory {
        let value=try history(record),h=value.mechanics
        guard physical.revision == model.stamp.revision,h.position == physical.q,h.velocity == physical.v,h.acceptedTime == physical.time,h.acceptedSequence == sequence else { throw RuntimeFailure(.invalidContributor,message:"Loaded history differs from actual checkpoint q/v/time/sequence.") };return value
    }
    internal func equation(drive:[Double],selection:StationaryLoadSelection,execution:any StationaryLoadExecuting) throws(RuntimeFailure) -> StationaryAffineMechanismEquation {
        let base:AffineMechanismEquation
        do throws(MechanismError) { base=try AffineMechanismEquation(identity:descriptor.identity,model:model,constraints:constraints,drive:drive,policy:solvePolicy,admission:admission,maximumIdentityBytes:policy.maximumIdentityBytes) }
        catch { throw RuntimeFailure(.invalidState,message:"Loaded physical equation construction failed.",failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        return try StationaryAffineMechanismEquation(base:base,catalog:catalog,selection:selection,execution:execution,maximumIdentityBytes:policy.maximumIdentityBytes)
    }
    internal func check() throws(RuntimeFailure) {
        guard !Task.isCancelled,!policy.thresholds.isCancelled(),!solvePolicy.isCancelled(),!admission.isCancelled() else { throw RuntimeFailure(.cancelled,message:"Loaded sleep operation cancelled.") }
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Generic record-only Runtime admission has no physical/time/sequence association. Loaded sleep requires LoadedSleepRuntimeCheckpointHandler's complete contextual admission before accepting a record.
    public func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        throw RuntimeFailure(.unsupportedDomain,message:"Loaded sleep validation requires the complete checkpoint.")
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Runtime topology replacement lacks target catalog/constraint/connected history authority. Explicit topology-load event migration and real target dynamics are required before this domain may accept migrated sleeping state.
    public func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        throw RuntimeFailure(.incompatibleMigration,message:"Loaded sleep topology migration is unsupported.")
    }
}
