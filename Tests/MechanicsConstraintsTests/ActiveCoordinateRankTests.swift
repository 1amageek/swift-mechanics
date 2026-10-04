import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ActiveCoordinateRankTests {
    private func sample(rows: [Double]? = nil, revision: UInt64 = 7) throws -> VelocityConstraintSample {
        let layout = try ConstraintCoordinateLayout(coordinateIDs: [10,20,30,40,50,60],
            dimensions: [.length,.length,.length,.angle,.angle,.angle], scales: [2,3,4,5,6,7], timeScale: 2, revision: revision)
        return VelocityConstraintSample(layout: layout, rowIDs: [101,102,103],
            rows: rows ?? [1,0,0,2,0,0, 0,1,0,0,3,0, 2,0,0,4,0,0],
            drift: [1,2,3], accelerationBias: [4,5,6], isIntegrable: false)
    }
    private func policy(rank: ConstraintRankPolicy = .allowRedundancy,
                        cancelled: @escaping @Sendable () -> Bool = { false }) throws -> ConstraintSolvePolicy {
        try ConstraintFixtures.policy(metric: [1,4,9,16,25,36], rank: rank, cancelled: cancelled)
    }

    @Test func requiredWitnessRetainsFullOriginalSampleAndRestrictedRank() throws {
        let input = try sample(), selectedPolicy = try policy()
        let operation: any ActiveCoordinateRankAnalyzing = WeightedConstraintAssembler()
        var work = try ConstraintFixtures.work()
        let result = try operation.rank(input, activeCoordinates: [3,4,5], policy: selectedPolicy, work: &work)
        #expect(result.originalCoordinateCount == 6 && result.activeCoordinateCount == 3 && result.originalRowCount == 3)
        #expect(result.activeCoordinates == [3,4,5])
        #expect(result.rank.rank == 2 && result.rank.independentRows == [0,1] && result.rank.dependentRowIDs == [103])
        #expect(result.rank.reactionNullity == 1 && !result.rank.reactionsUnique)
        #expect(result.sample.rows == input.rows && result.sample.rowIDs == input.rowIDs)
        #expect(result.sample.drift == input.drift && result.sample.accelerationBias == input.accelerationBias && !result.sample.isIntegrable)
        #expect(result.sample.layout.coordinateIDs == input.layout.coordinateIDs && result.sample.layout.dimensions == input.layout.dimensions)
        #expect(result.sample.layout.scales == input.layout.scales && result.sample.layout.timeScale == 2 && result.sample.layout.revision == 7)
        #expect(result.policy.diagonalMetric == selectedPolicy.diagonalMetric && result.policy.rankRelativeTolerance == selectedPolicy.rankRelativeTolerance)
        #expect(work.operations > 0 && work.iterations == 0 && work.peakScalarStorage == 51)
        var reorderedWork = try ConstraintFixtures.work()
        let reordered = try operation.rank(input, activeCoordinates: [5,4,3], policy: selectedPolicy, work: &reorderedWork)
        #expect(reordered.activeCoordinates == [5,4,3] && reordered.rank.independentRows == result.rank.independentRows)
        var fullWork = try ConstraintFixtures.work(), oldWork = try ConstraintFixtures.work()
        let full = try operation.rank(input, activeCoordinates: [0,1,2,3,4,5], policy: selectedPolicy, work: &fullWork)
        let old = try WeightedConstraintAssembler().rank(input, policy: selectedPolicy, work: &oldWork)
        #expect(full.rank.rank == old.rank && full.rank.independentRows == old.independentRows && full.rank.dependentRowIDs == old.dependentRowIDs)
    }

    @Test func emptyDynamicTangentRetainsEveryOriginalRowAsDependent() throws {
        let input = try sample(), selectedPolicy = try policy(), independent = try policy(rank: .requireIndependentRows)
        var work = try ConstraintFixtures.work()
        let result = try WeightedConstraintAssembler().rank(input, activeCoordinates: [], policy: selectedPolicy, work: &work)
        #expect(result.originalCoordinateCount == 6 && result.originalRowCount == 3 && result.activeCoordinateCount == 0)
        #expect(result.rank.rank == 0 && result.rank.independentRows.isEmpty && result.rank.dependentRowIDs == input.rowIDs)
        #expect(result.rank.reactionNullity == 3 && result.sample.rows == input.rows)
        do throws(ConstraintError) {
            _ = try WeightedConstraintAssembler().rank(input, activeCoordinates: [], policy: independent, work: &work)
            Issue.record("Restricted ambiguity ignored")
        } catch { if case .rankAmbiguity(let rank, let rows) = error { #expect(rank == 0 && rows == 3) } else { Issue.record("Wrong ambiguity failure") } }
    }

    @Test func zeroOriginalRowsAreHonestOnlyUnderAdditiveSemantics() throws {
        let original = try sample(), selectedPolicy = try policy(rank: .requireIndependentRows)
        let empty = VelocityConstraintSample(layout: original.layout, rowIDs: [], rows: [], drift: [], accelerationBias: [], isIntegrable: true)
        for indices in [[Int](), [3,4,5]] {
            var work = try ConstraintFixtures.work()
            let result = try WeightedConstraintAssembler().rank(empty, activeCoordinates: indices, policy: selectedPolicy, work: &work)
            #expect(result.rank.rank == 0 && result.rank.reactionNullity == 0 && result.rank.reactionsUnique)
            #expect(result.originalRowCount == 0 && result.originalCoordinateCount == 6 && result.sample.rows.isEmpty)
            #expect(result.activeCoordinates == indices && work.operations > 0)
        }
        var work = try ConstraintFixtures.work()
        do throws(ConstraintError) { _ = try WeightedConstraintAssembler().rank(empty, policy: selectedPolicy, work: &work); Issue.record("Legacy row admission changed") }
        catch { if case .invalidDimensions = error {} else { Issue.record("Wrong legacy zero-row failure") } }
    }

    @Test func inactiveRowsIndicesAndStaleLayoutRemainValidated() throws {
        let original = try sample(), selectedPolicy = try policy()
        for indices in [[3,3], [-1], [6], [0,1,2,3,4,5,6]] {
            var work = try ConstraintFixtures.work()
            do throws(ConstraintError) { _ = try WeightedConstraintAssembler().rank(original, activeCoordinates: indices, policy: selectedPolicy, work: &work); Issue.record("Invalid active index admitted") }
            catch {
                if indices == [3,3] { if case .invalidInput = error {} else { Issue.record("Wrong duplicate-index failure") } }
                else { if case .invalidDimensions = error {} else { Issue.record("Wrong index failure") } }
            }
        }
        var rows = original.rows; rows[0] = .nan
        let inactiveNaN = try sample(rows: rows), stale = try sample(revision: 8)
        let malformed = VelocityConstraintSample(layout: original.layout, rowIDs: original.rowIDs, rows: [1], drift: original.drift,
            accelerationBias: original.accelerationBias, isIntegrable: original.isIntegrable)
        for (index, input) in [inactiveNaN, stale, malformed].enumerated() {
            var work = try ConstraintFixtures.work()
            do throws(ConstraintError) { _ = try WeightedConstraintAssembler().rank(input, activeCoordinates: [], policy: selectedPolicy, work: &work); Issue.record("Original input discarded") }
            catch {
                switch (index,error) { case (0,.invalidInput),(1,.staleLayout),(2,.invalidDimensions): break; default: Issue.record("Wrong original input failure") }
            }
        }
    }

    @Test func storageWorkCapacityAndCancellationCannotPublish() throws {
        let input = try sample(), selectedPolicy = try policy(), cancelled = try policy(cancelled: { true })
        for storage in [false, true] {
            var work = try ConstraintFixtures.work(storage: storage ? 50 : 10000, operations: storage ? 100000 : 1)
            do throws(ConstraintError) { _ = try WeightedConstraintAssembler().rank(input, activeCoordinates: [3,4,5], policy: selectedPolicy, work: &work); Issue.record("Resource bound ignored") }
            catch { if case .numerical(.resourceLimit(let resource,_)) = error { #expect(resource == (storage ? .scalarStorage : .arithmeticOperations)) } else { Issue.record("Wrong bounded-work failure") } }
            #expect(work.operations <= work.budget.arithmeticOperations && work.peakScalarStorage <= work.budget.scalarStorage)
        }
        var work = try ConstraintFixtures.work()
        do throws(ConstraintError) { _ = try WeightedConstraintAssembler().rank(input, activeCoordinates: [], policy: cancelled, work: &work); Issue.record("Cancellation ignored") }
        catch { if case .cancelled = error { #expect(work.operations == 0) } else { Issue.record("Wrong cancellation failure") } }
        let limitedEvaluation = try ConstraintEvaluationPolicy(maximumCoordinates: 5, maximumRows: 3, expectedLayoutRevision: 7)
        let limited = try ConstraintSolvePolicy(evaluation: limitedEvaluation, diagonalMetric: selectedPolicy.diagonalMetric,
            energyScale: selectedPolicy.energyScale, rankPolicy: selectedPolicy.rankPolicy, rankRelativeTolerance: selectedPolicy.rankRelativeTolerance,
            originalResidualTolerance: selectedPolicy.originalResidualTolerance, maximumCorrection: selectedPolicy.maximumCorrection,
            nonlinear: selectedPolicy.nonlinear, linearCapability: selectedPolicy.linearCapability, linearTolerance: selectedPolicy.linearTolerance)
        do throws(ConstraintError) { _ = try WeightedConstraintAssembler().rank(input, activeCoordinates: [], policy: limited, work: &work); Issue.record("Full-layout capacity ignored") }
        catch { if case .capacityExceeded = error {} else { Issue.record("Wrong capacity failure") } }
    }
}
