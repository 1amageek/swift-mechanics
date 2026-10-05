import SwiftMechanics
import Synchronization
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class IslandSleepParticipant: IslandEndpointContributing,Sendable {
    let schema:RuntimeContributorSchema
    var schemas:[RuntimeContributorSchema] { [schema] }
    private let reset=Mutex(false)
    private let validationBudget:NumericalBudget
    init() throws {
        schema=try RuntimeContributorSchema(id:"test.mixed.endpoint",category:.event,version:1,maximumBytes:16)
        validationBudget=try NumericalBudget(scalarStorage:16,arithmeticOperations:16,iterations:0)
    }
    func breakLedger() { reset.withLock { $0=true } }
    func recordEndpoint(source:RuntimeCheckpoint,physical:KinematicState,acceptedSequence:UInt64,work:inout NumericalWork) throws(RuntimeFailure) -> RuntimeContributorState {
        if reset.withLock({$0}) { work=NumericalWork(budget:work.budget) }
        else { do throws(NumericalError) { try work.requireStorage(16);try work.chargeOperations(16) } catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Test participant work.") } }
        var bytes:[UInt8]=[]
        for word in [physical.time.bitPattern,acceptedSequence] { for shift in stride(from:0,to:64,by:8) { bytes.append(UInt8(truncatingIfNeeded:word >> shift)) } }
        return try RuntimeContributorState(id:schema.id,category:schema.category,version:schema.version,bytes:bytes)
    }
    func validateAssociation(record:RuntimeContributorState,physical:KinematicState,acceptedSequence:UInt64,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        var work=NumericalWork(budget:validationBudget)
        let dummy=try RuntimeCheckpoint(model:ModelStamp(identity:"participant-only",revision:physical.revision),continuation:RuntimeContinuationIdentity(build:"test",backend:"test",precision:"float64"),physical:physical,contributors:[],random:RuntimeRandomState(seed:0),acceptedSteps:0)
        let wanted=try recordEndpoint(source:dummy,physical:physical,acceptedSequence:acceptedSequence,work:&work)
        guard record == wanted,budget.workUnits >= 16,budget.scratchBytes >= 16 else { throw RuntimeFailure(.invalidContributor,message:"Actual participant history/time/global sequence differs.") }
        return try RuntimeValidationEvidence(workUnitsUsed:16,scratchBytesUsed:16)
    }
    func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence { throw RuntimeFailure(.unsupportedDomain,message:"Test participant requires context.") }
    func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState { throw RuntimeFailure(.incompatibleMigration,message:"No test topology path.") }
}
