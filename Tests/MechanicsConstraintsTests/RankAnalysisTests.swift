import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct RankAnalysisTests {
    private func sample(rows: [Double] = [2,0,0,3,4,0], ids: [UInt64] = [10,20,30],
                        drift: [Double] = [1,2,3], bias: [Double] = [4,5,6],
                        revision: UInt64 = 7) throws -> VelocityConstraintSample {
        let source=try ConstraintFixtures.layout(scales:[2,3],timeScale:4)
        let layout=try ConstraintCoordinateLayout(coordinateIDs:source.coordinateIDs,
            dimensions:source.dimensions,scales:source.scales,timeScale:source.timeScale,revision:revision)
        return VelocityConstraintSample(layout:layout,rowIDs:ids,rows:rows,
            drift:drift,accelerationBias:bias,isIntegrable:false)
    }

    @Test func requiredProtocolReportsRetainedRowsWithoutInferringFeasibility() throws {
        let operation: any ConstraintRankAnalyzing=WeightedConstraintAssembler()
        var work=try ConstraintFixtures.work()
        let result=try operation.rank(sample(),policy:ConstraintFixtures.policy(metric:[4,9]),work:&work)
        #expect(result.rank == 2)
        #expect(result.independentRows == [0,1])
        #expect(result.dependentRowIDs == [30])
        #expect(result.reactionNullity == 1)
        #expect(!result.reactionsUnique)
        #expect(work.operations > 0)
        #expect(work.iterations == 0)
        #expect(work.peakScalarStorage == 30)
    }

    @Test func zeroRowsAndIndependencePolicyHaveDifferentActualOutcomes() throws {
        var work=try ConstraintFixtures.work()
        let zero=try sample(rows:[0,0,0,0,0,0])
        let result=try WeightedConstraintAssembler().rank(zero,policy:ConstraintFixtures.policy(),work:&work)
        #expect(result.rank == 0)
        #expect(result.independentRows.isEmpty)
        #expect(result.dependentRowIDs == [10,20,30])
        work=try ConstraintFixtures.work()
        do {
            _=try WeightedConstraintAssembler().rank(sample(),policy:ConstraintFixtures.policy(rank:.requireIndependentRows),work:&work)
            Issue.record("Expected retained-row ambiguity.")
        } catch let error as ConstraintError {
            if case .rankAmbiguity(let rank,let rows)=error { #expect(rank == 2); #expect(rows == 3) }
            else { Issue.record("Wrong failure: \(error)") }
        }
    }

    @Test func malformedStaleDuplicateAndNonfiniteSamplesFail() throws {
        let cases: [VelocityConstraintSample]=[
            try sample(rows:[1]),try sample(revision:8),try sample(ids:[10,10,30]),
            try sample(rows:[.nan,0,0,3,4,0]),try sample(drift:[.infinity,2,3]),try sample(bias:[4,5,.nan])]
        for (index,input) in cases.enumerated() {
            var work=try ConstraintFixtures.work()
            do { _=try WeightedConstraintAssembler().rank(input,policy:ConstraintFixtures.policy(),work:&work); Issue.record("Expected sample rejection.") }
            catch let error as ConstraintError {
                switch (index,error) {
                case (0,.invalidDimensions),(1,.staleLayout),(2...5,.invalidInput): break
                default: Issue.record("Wrong failure: \(error)")
                }
            }
        }
    }

    @Test func storageOperationsAndCancellationPreventPublication() throws {
        for storage in [false,true] {
            var work=try ConstraintFixtures.work(storage:storage ? 29 : 1000,operations:storage ? 1000 : 0)
            do { _=try WeightedConstraintAssembler().rank(sample(),policy:ConstraintFixtures.policy(),work:&work); Issue.record("Expected bounded-work rejection.") }
            catch let error as ConstraintError {
                if case .numerical(.resourceLimit(let resource,_))=error {
                    #expect(resource == (storage ? .scalarStorage : .arithmeticOperations))
                } else { Issue.record("Wrong failure: \(error)") }
            }
        }
        var work=try ConstraintFixtures.work()
        do { _=try WeightedConstraintAssembler().rank(sample(),policy:ConstraintFixtures.policy(cancelled:{true}),work:&work); Issue.record("Expected cancellation.") }
        catch let error as ConstraintError {
            if case .cancelled=error { #expect(work.operations == 0) }
            else { Issue.record("Wrong failure: \(error)") }
        }
    }
}
