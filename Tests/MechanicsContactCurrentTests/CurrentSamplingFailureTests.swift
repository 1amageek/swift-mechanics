import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct CurrentSamplingFailureTests {
    @Test func loadDecreaseAndOpeningRefuseRatherThanRepairAcceptedBristles() throws {
        let pair=try CurrentContactFixtures.pair(friction:CurrentContactFixtures.friction())
        let issued=try CurrentContactFixtures.evaluate(CurrentContactFixtures.input(velocity:Vector3(5,0,0)),pair:pair).trialHistory
        #expect(throws:ContactCurrentError.inadmissibleAcceptedTraction(utilization:3.125,threshold:1+1e-11)) {
            try CurrentContactFixtures.sample(CurrentContactFixtures.current(separation:-0.002,time:0.001),pair:pair,accepted:issued)
        }
        #expect(throws:ContactCurrentError.unloadedBristles) {
            try CurrentContactFixtures.sample(CurrentContactFixtures.current(separation:0.1,time:0.001),pair:pair,accepted:issued)
        }
        #expect(issued.firstBristleDisplacement == 0.005 && issued.sequence == 1)
        // The original trial still performs its distinct release/return operation.
        let trial=try CurrentContactFixtures.evaluate(CurrentContactFixtures.input(separation:0.1,time:0.001),pair:pair,accepted:issued)
        #expect(trial.frictionRegime == .released && trial.trialHistory.firstBristleDisplacement == 0)
        #expect(CurrentContactFixtures.close(trial.tangentialDissipationEnergy,0.0125))
    }

    @Test func exactTimePairAndRevisionAssociationAndFramedInputAreRequired() throws {
        let pair=try CurrentContactFixtures.pair(),history=try CurrentContactFixtures.history(pair)
        for input in [try CurrentContactFixtures.current(time:0.1),
                      try CurrentContactFixtures.current(identity:CurrentContactFixtures.identity(geometryRevision:2)),
                      try CurrentContactFixtures.current(identity:CurrentContactFixtures.identity(layoutRevision:2))] {
            #expect(throws:ContactCurrentError.law(.staleHistory)) { try CurrentContactFixtures.sample(input,pair:pair,accepted:history) }
        }
        let changed=try CurrentContactFixtures.pair(damping:2)
        #expect(throws:ContactCurrentError.law(.staleHistory)) { try CurrentContactFixtures.sample(CurrentContactFixtures.current(),pair:changed,accepted:history) }
        #expect(throws:ContactCurrentError.law(.invalidInput)) { try CurrentContactFixtures.current(time:-1) }
        #expect(throws:ContactCurrentError.law(.invalidInput)) { try CurrentContactFixtures.current(separation:.nan) }
        let id=try CurrentContactFixtures.identity(),basis=try ContactBasis(frame:CurrentContactFixtures.reference("other",kind:.frame),contactToQuery:.identity)
        #expect(throws:ContactCurrentError.law(.frameMismatch)) {
            try ContactCurrentInput(identity:id,basis:basis,separation:-0.01,relativeVelocity:.zero,relativeAngularVelocity:.zero,timeSeconds:0)
        }
        #expect(history.sequence == 0 && history.timeSeconds == 0)
    }

    @Test func normalDomainAndActualArithmeticFailureRetainTypedUnderlyingCause() throws {
        let pair=try CurrentContactFixtures.pair(selection:.hertz(effectiveRadius:0.1,maximumPenetration:0.01,maximumNormalSpeed:10))
        #expect(throws:ContactCurrentError.law(.normalDomain)) { try CurrentContactFixtures.sample(CurrentContactFixtures.current(separation:-0.02),pair:pair) }
        #expect(throws:ContactCurrentError.law(.normalDomain)) { try CurrentContactFixtures.sample(CurrentContactFixtures.current(velocity:Vector3(0,0,11)),pair:pair) }
        var work=try CurrentContactFixtures.work(); let pairing:any ContactMaterialPairing=SeriesContactPairing()
        let huge=try pairing.combine(first:CurrentContactFixtures.material("hugeA",stiffness:1e308,damping:1e308),
            second:CurrentContactFixtures.material("hugeB",stiffness:1e308,damping:1e308),
            selection:.linear(maximumPenetration:1,maximumNormalSpeed:1e300),lossPolicy:.compliantDampingOnly,resistanceRadius:1,override:nil,work:&work)
        let history=try CurrentContactFixtures.history(huge)
        #expect(throws:ContactCurrentError.law(.arithmeticFailure)) {
            try CurrentContactFixtures.sample(CurrentContactFixtures.current(separation:-0.5,velocity:Vector3(0,0,-1e200)),pair:huge,accepted:history)
        }
        #expect(history.sequence == 0 && history.cumulativeTangentialDissipation == 0)
    }

    @Test func operationStorageAndRecordBudgetsAreCheckedBeforeSamplingAndExactWorkIsRetained() throws {
        let sampler:any ContactCurrentEvaluating=CompliantContactCurrentEvaluator()
        let pair=try CurrentContactFixtures.pair(),history=try CurrentContactFixtures.history(pair),input=try CurrentContactFixtures.current(),policy=try CurrentContactFixtures.policy()
        var operations=try CurrentContactFixtures.work(operations:4095),storage=try CurrentContactFixtures.work(storage:511),records=try CurrentContactFixtures.work(records:0)
        #expect(throws:ContactCurrentError.law(.resourceLimit(resource:.operations,limit:4095))) { try sampler.sample(input:input,pair:pair,accepted:history,policy:policy,work:&operations) }
        #expect(throws:ContactCurrentError.law(.resourceLimit(resource:.scalarStorage,limit:511))) { try sampler.sample(input:input,pair:pair,accepted:history,policy:policy,work:&storage) }
        #expect(throws:ContactCurrentError.law(.resourceLimit(resource:.records,limit:0))) { try sampler.sample(input:input,pair:pair,accepted:history,policy:policy,work:&records) }
        var exact=try CurrentContactFixtures.work(operations:4168,storage:512,records:1)
        _=try sampler.sample(input:input,pair:pair,accepted:history,policy:policy,work:&exact)
        #expect(exact.operations == 4168 && exact.peakScalarStorage == 512)
        #expect(history.sequence == 0 && history.firstBristleDisplacement == 0)
    }

    @Test func longMetadataTraversalCannotBypassWorkBeforeHistoryEquality() throws {
        let base=try CurrentContactFixtures.identity(),pair=try CurrentContactFixtures.pair()
        let identity=try ContactIdentity(key:String(repeating:"x",count:3000),firstBody:base.firstBody,secondBody:base.secondBody,frame:base.frame,
            firstGeometryRevision:1,secondGeometryRevision:1,tangentLayoutRevision:1)
        let history=try CurrentContactFixtures.history(pair,identity:identity),input=try CurrentContactFixtures.current(identity:identity)
        var work=try CurrentContactFixtures.work(operations:5000)
        let sampler:any ContactCurrentEvaluating=CompliantContactCurrentEvaluator()
        #expect(throws:ContactCurrentError.law(.resourceLimit(resource:.operations,limit:5000))) { try sampler.sample(input:input,pair:pair,accepted:history,policy:CurrentContactFixtures.policy(),work:&work) }
        #expect(work.operations == 5000 && history.sequence == 0)
    }

    @Test func cancelledCurrentSamplingLeavesIssuedHistoryIntact() async throws {
        let pair=try CurrentContactFixtures.pair(friction:CurrentContactFixtures.friction())
        let issued=try CurrentContactFixtures.evaluate(CurrentContactFixtures.input(velocity:Vector3(1,0,0)),pair:pair).trialHistory
        let input=try CurrentContactFixtures.current(time:0.001),policy=try CurrentContactFixtures.policy()
        let task=Task {
            while !Task.isCancelled { await Task.yield() }
            var work=try CurrentContactFixtures.work(); let sampler:any ContactCurrentEvaluating=CompliantContactCurrentEvaluator()
            return try sampler.sample(input:input,pair:pair,accepted:issued,policy:policy,work:&work)
        }
        task.cancel()
        do { _=try await task.value; Issue.record("Cancelled sampling must fail") }
        catch { #expect(error as? ContactCurrentError == .law(.cancelled)) }
        #expect(issued.sequence == 1 && issued.timeSeconds == 0.001 && issued.firstBristleDisplacement == 0.001)
    }
}
