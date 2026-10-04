import SwiftMechanics
import Testing
struct LocalMinimumFailureTests {
    @Test func saddleRootCannotBecomeStrictLocalMinimum() throws {
        let e=try failure(LocalOptimizationFixtures.problem(.saddle))
        if case .numerical(.nonPositiveDefinite(let pivot))=e.cause { #expect(pivot == 1) } else { Issue.record("Expected negative reduced curvature") }
        #expect(e.phase == .reducedCurvature && e.failedSupplierWorkUnavailable)
    }
    @Test func weakActiveMaximumFailsDespiteZeroDimensionalNullspace() throws {
        let e=try failure(LocalOptimizationFixtures.problem(.weakActive))
        if case .weaklyActive(let index,let multiplier)=e.cause { #expect(index == 0 && multiplier == 0) } else { Issue.record("Expected explicit critical-cone refusal") }
        #expect(e.phase == .originalCertificate && !e.failedSupplierWorkUnavailable)
    }
    @Test func dependentAndIndeterminateConstraintRanksStayDistinct() throws {
        let dependent=try failure(LocalOptimizationFixtures.problem(.rank))
        if case .rankDeficient(let rank,let rows)=dependent.cause { #expect(rank == 1 && rows == 2) } else { Issue.record("Expected dependent equality gradients") }
        let near=try failure(LocalOptimizationFixtures.problem(.nearRank))
        if case .rankIndeterminate(let pivot,let threshold)=near.cause { #expect(pivot > 0 && pivot < threshold) } else { Issue.record("Expected numerical rank uncertainty") }
        #expect(dependent.phase == .rank && near.phase == .rank)
    }
    @Test func underlyingSingularKktPreservesActualFailureAndKnownWork() throws {
        let e=try failure(LocalOptimizationFixtures.problem(.singular))
        if case .nonlinear(let underlying)=e.cause {
            #expect(underlying.cause == .numerical(.singular(rank:0,pivot:0)))
            #expect(underlying.failedSupplierWorkUnavailable && underlying.work.operations > 0)
            #expect(e.work.operations >= underlying.work.operations)
        } else { Issue.record("Expected actual failed nonlinear linear supplier") }
        #expect(e.phase == .nonlinearSolve && e.failedSupplierWorkUnavailable)
    }
    @Test func falseInternalResidualIsRejectedByActualOriginalEquation() throws {
        let e=try failure(LocalOptimizationFixtures.problem(.dishonest))
        if case .nonlinear(let underlying)=e.cause {
            if case .originalResidualDisagreement(let internalNorm,let originalNorm,let threshold)=underlying.cause { #expect(internalNorm == 0 && originalNorm > threshold) }
            else { Issue.record("Expected original residual disagreement") }
        } else { Issue.record("Expected actual original acceptance failure") }
        #expect(!e.failedSupplierWorkUnavailable)
    }
    @Test func successfulDifferentRootSupplierStillNeedsOriginalKktProof() throws {
        let e=try failure(LocalOptimizationFixtures.problem(),service:FixedActiveLocalOptimizer(nonlinear:DifferentProblemNonlinearSolver<Double>()))
        if case .certificateRejected=e.cause {} else { Issue.record("Expected independent original certificate rejection") }
        #expect(e.phase == .originalCertificate && !e.failedSupplierWorkUnavailable)
        #expect((e.lastOriginalKKTResidual ?? 0) > 0.1)
    }
    @Test func missingConstraintHessianFailsActualDerivativeProbe() throws {
        let e=try failure(LocalOptimizationFixtures.problem(.badHessian))
        if case .nonlinear(let underlying)=e.cause {
            if case .invalidDerivative(let observed,let threshold)=underlying.cause { #expect(observed > threshold) } else { Issue.record("Expected missing constraint-Hessian term to fail") }
        } else { Issue.record("Expected actual directional derivative gate") }
    }
    @Test func poisonedOrResizedCallbackIsNeverAccepted() throws {
        for mode in [ManufacturedSmoothProgram<Double>.Mode.partial,.resized] {
            let e=try failure(LocalOptimizationFixtures.problem(mode))
            if case .nonlinear(let underlying)=e.cause { #expect(underlying.cause == .invalidEvaluation) } else { Issue.record("Expected malformed callback rejection") }
            #expect(!e.failedSupplierWorkUnavailable)
        }
    }
    @Test func callbackLedgerResetPreservesKnownWorkAndMarksUnknown() throws {
        let e=try failure(LocalOptimizationFixtures.problem(.ledgerReset))
        #expect(e.failedSupplierWorkUnavailable && e.phase == .nonlinearSolve)
        if case .nonlinear(let underlying)=e.cause { #expect(underlying.cause == .equation(.evaluationFailed(code:Int.min))) } else { Issue.record("Expected invalid callback ledger") }
    }
    @Test func customAndDomainFailuresRemainTyped() throws {
        for mode in [ManufacturedSmoothProgram<Double>.Mode.customFailure,.domainFailure] {
            let e=try failure(LocalOptimizationFixtures.problem(mode))
            if case .nonlinear(let underlying)=e.cause {
                #expect(underlying.cause == (mode == .customFailure ? .equation(.evaluationFailed(code:17)) : .equation(.outsideDomain)))
            } else { Issue.record("Expected retained callback cause") }
        }
    }
    @Test func workStorageIterationAndFillBoundariesCannotPublish() throws {
        let p=try LocalOptimizationFixtures.problem()
        let arithmetic=try failure(p,initialWork:LocalOptimizationFixtures.work(operations:0))
        if case .callback(.numerical(.resourceLimit(let resource,let limit)))=arithmetic.cause { #expect(resource == .arithmeticOperations && limit == 0) } else { Issue.record("Expected arithmetic budget failure") }
        let storage=try failure(p,initialWork:LocalOptimizationFixtures.work(storage:0))
        if case .numerical(.resourceLimit(let resource,let limit))=storage.cause { #expect(resource == .scalarStorage && limit == 0) } else { Issue.record("Expected storage preflight failure") }
        let iteration=try failure(p,initialWork:LocalOptimizationFixtures.work(iterations:0))
        if case .nonlinear(let underlying)=iteration.cause { #expect(underlying.cause == .numerical(.resourceLimit(resource:.iterations,limit:0))) } else { Issue.record("Expected actual nested iteration boundary") }
        #expect(arithmetic.work.operations == 0 && storage.work.operations == 0 && iteration.work.iterations == 0)
        let fill=try failure(p,policy:LocalOptimizationFixtures.policy(fill:0))
        if case .capacity(let required,let limit)=fill.cause { #expect(required == 9 && limit == 0) } else { Issue.record("Expected explicit dense fill admission") }
    }
    @Test func cancellationDoesNotMutateInitialAcceptedData() throws {
        let p=try LocalOptimizationFixtures.problem(),e=try failure(p,policy:LocalOptimizationFixtures.policy(cancel:{true}))
        if case .callback(.numerical(.cancelled))=e.cause {} else { Issue.record("Expected cancellation") }
        #expect(e.work.operations == 0 && p.initialPoint == [0.8,0.8])
    }
    private func failure(_ p: FixedActiveNonlinearProblem,policy: LocalOptimizationPolicy? = nil,initialWork: NumericalWork? = nil,
        service: any LocalOptimizationSolving = FixedActiveLocalOptimizer()) throws -> LocalOptimizationFailure {
        var work=try initialWork ?? LocalOptimizationFixtures.work()
        do { _=try service.solve(p,policy:policy ?? LocalOptimizationFixtures.policy(),work:&work); Issue.record("Expected typed local optimization failure"); throw LocalOptimizationCause.invalidProblem }
        catch let error as LocalOptimizationFailure { #expect(error.work == work); return error }
    }
}
