import MechanicsContactLaws
import MechanicsCore
import MechanicsModel
import Testing

@Suite(.timeLimit(.minutes(1)))
struct HistoryAndFailureTests {
    @Test func wrongTimeStepZeroFrameGeometryAndPairCannotProduceAcceptedEnergy() throws {
        let pair=try ContactFixtures.pair(friction:ContactFixtures.friction())
        let history=try ContactFixtures.history(pair)
        #expect(throws:ContactLawError.invalidInput) { try ContactFixtures.input(step:0) }
        #expect(throws:ContactLawError.invalidInput) { try ContactFixtures.input(separation:.nan) }
        #expect(throws:ContactLawError.staleHistory) { try ContactFixtures.evaluate(ContactFixtures.input(time:0.1),pair:pair,accepted:history) }
        #expect(throws:ContactLawError.staleHistory) { try ContactFixtures.evaluate(ContactFixtures.input(identity:ContactFixtures.identity(geometryRevision:2)),pair:pair,accepted:history) }
        #expect(throws:ContactLawError.staleHistory) { try ContactFixtures.evaluate(ContactFixtures.input(identity:ContactFixtures.identity(layoutRevision:2)),pair:pair,accepted:history) }
        let changed=try ContactFixtures.pair(damping:2,friction:ContactFixtures.friction())
        #expect(throws:ContactLawError.staleHistory) { try ContactFixtures.evaluate(ContactFixtures.input(),pair:changed,accepted:history) }
        let id=try ContactFixtures.identity()
        let basis=try ContactBasis(frame:ContactFixtures.reference("elsewhere",kind:.frame),contactToQuery:.identity)
        #expect(throws:ContactLawError.frameMismatch) { try ContactInput(identity:id,basis:basis,separation:-0.01,relativeVelocity:.zero,relativeAngularVelocity:.zero,startTimeSeconds:0,timeStepSeconds:0.01) }
        #expect(history.sequence == 0 && history.timeSeconds == 0 && history.firstBristleDisplacement == 0)
    }
    @Test func overflowCapacityStorageAndWorkFailWithoutMutatingHistory() throws {
        let evaluator:any ContactLawEvaluating=CompliantContactEvaluator()
        let pair=try ContactFixtures.pair(),history=try ContactFixtures.history(pair),input=try ContactFixtures.input()
        var capacity=try ContactFixtures.work(records:0),storage=try ContactFixtures.work(storage:0),operations=try ContactFixtures.work(operations:0)
        #expect(throws:ContactLawError.resourceLimit(resource:.records,limit:0)) { try evaluator.evaluate(input:input,pair:pair,accepted:history,policy:ContactFixtures.policy(),work:&capacity) }
        #expect(throws:ContactLawError.resourceLimit(resource:.scalarStorage,limit:0)) { try evaluator.evaluate(input:input,pair:pair,accepted:history,policy:ContactFixtures.policy(),work:&storage) }
        #expect(throws:ContactLawError.resourceLimit(resource:.operations,limit:0)) { try evaluator.evaluate(input:input,pair:pair,accepted:history,policy:ContactFixtures.policy(),work:&operations) }
        let materialA=try ContactFixtures.material("largeA",stiffness:1e308,damping:1e308)
        let materialB=try ContactFixtures.material("largeB",stiffness:1e308,damping:1e308)
        var work=try ContactFixtures.work(); let pairing:any ContactMaterialPairing=SeriesContactPairing()
        let huge=try pairing.combine(first:materialA,second:materialB,selection:.linear(maximumPenetration:1,maximumNormalSpeed:1e300),lossPolicy:.compliantDampingOnly,resistanceRadius:1,override:nil,work:&work)
        #expect(throws:ContactLawError.arithmeticFailure) { try ContactFixtures.evaluate(ContactFixtures.input(separation:-0.5,velocity:Vector3(0,0,-1e200)),pair:huge) }
        #expect(history.sequence == 0 && history.cumulativeTangentialDissipation == 0)
    }
    @Test func longMetadataCannotBypassCallerWorkBudget() throws {
        let base=try ContactFixtures.identity(),pair=try ContactFixtures.pair()
        let identity=try ContactIdentity(key:String(repeating:"x",count:3000),firstBody:base.firstBody,secondBody:base.secondBody,frame:base.frame,
            firstGeometryRevision:1,secondGeometryRevision:1,tangentLayoutRevision:1)
        let input=try ContactFixtures.input(identity:identity),history=try ContactFixtures.history(pair,identity:identity)
        var work=try ContactFixtures.work(operations:5000)
        let evaluator:any ContactLawEvaluating=CompliantContactEvaluator()
        #expect(throws:ContactLawError.resourceLimit(resource:.operations,limit:5000)) {
            try evaluator.evaluate(input:input,pair:pair,accepted:history,policy:ContactFixtures.policy(),work:&work)
        }
        #expect(history.sequence == 0)
    }
    @Test func cancelledEvaluationFailsBeforeAnyTrialAcceptance() async throws {
        let pair=try ContactFixtures.pair(),history=try ContactFixtures.history(pair),input=try ContactFixtures.input(),policy=try ContactFixtures.policy()
        let task=Task {
            while !Task.isCancelled { await Task.yield() }
            var work=try ContactFixtures.work(); let evaluator:any ContactLawEvaluating=CompliantContactEvaluator()
            return try evaluator.evaluate(input:input,pair:pair,accepted:history,policy:policy,work:&work)
        }
        task.cancel()
        do { _=try await task.value; Issue.record("Cancellation must fail") }
        catch { #expect(error as? ContactLawError == .cancelled) }
        #expect(history.sequence == 0)
    }
}
