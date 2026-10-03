import MechanicsModel
import MechanicsNumerics
import MechanicsOptimization
import Testing

struct OptimizationFailureTests {
    @Test func dependentEqualityAdmissionAndNearRankAreDifferentFailures() throws {
        let dependent=try OptimizationFixtures.problem(cost:[0,0],equality:[[1,1],[2,2]],eqRHS:[1,2])
        let first=try failure(dependent)
        if case .dependentEqualityRows(let rank,let rows)=first.cause { #expect(rank == 1); #expect(rows == 2) } else { Issue.record("Expected equality rank rejection") }
        #expect(first.phase == .equalityRank); #expect(first.processedBases == 0); #expect(!first.failedSupplierWorkUnavailable)
        let small=try OptimizationFixtures.problem(cost:[0,0],equality:[[1,0],[0,1e-16]],eqRHS:[0,0])
        let second=try failure(small)
        if case .rankIndeterminate(let pivot,let threshold)=second.cause { #expect(pivot > 0 && pivot <= threshold) } else { Issue.record("Expected indeterminate rank") }
        #expect(second.termination == .rankIndeterminate); #expect(second.processedBases == 0)
    }
    @Test func indefiniteAndNonsymmetricCurvatureStopActualCholesky() throws {
        for h in [[-1.0,0,0,1],[1.0,1,0,1]] {
            let e=try failure(OptimizationFixtures.problem(cost:[0,0],hessian:h))
            if case .numerical(let cause)=e.cause {
                #expect(cause == .nonPositiveDefinite(pivot:0) || cause == .nonsymmetric)
            } else { Issue.record("Expected actual Cholesky failure") }
            #expect(e.phase == .linearSolve); #expect(e.processedBases == 0); #expect(e.failedSupplierWorkUnavailable)
        }
    }
    @Test func invalidBoundsAndInfiniteBoxNeverProduceInfeasibility() throws {
        let invalid=try failure(OptimizationFixtures.problem(cost:[1],lower:[1],upper:[0]))
        #expect(invalid.termination == .invalidProblem)
        let unsupported=try failure(OptimizationFixtures.problem(cost:[1],lower:[-.infinity],upper:[1]))
        #expect(unsupported.termination == .unsupportedDomain); #expect(unsupported.processedBases == 0)
    }
    @Test func candidateLimitIsNonconvergedEvenAfterAcceptedCandidate() throws {
        let e=try failure(OptimizationFixtures.problem(cost:[1]),policy:OptimizationFixtures.policy(candidates:1))
        #expect(e.termination == .nonconverged); #expect(e.processedBases == 1)
        #expect(e.lastFeasibilityResidual == 0); #expect(!e.failedSupplierWorkUnavailable)
    }
    @Test func arithmeticAndStorageBudgetsFailBeforeUnboundedWork() throws {
        let p=try OptimizationFixtures.problem(cost:[1])
        for w in [try OptimizationFixtures.work(operations:0),try OptimizationFixtures.work(storage:0)] {
            let e=try failure(p,initialWork:w)
            #expect(e.termination == .resourceLimit); #expect(e.processedBases == 0)
            #expect(e.work.operations == 0); #expect(!e.failedSupplierWorkUnavailable)
        }
    }
    @Test func iterationAndFillBudgetsRemainExplicit() throws {
        let p=try OptimizationFixtures.problem(cost:[1])
        let iteration=try failure(p,initialWork:OptimizationFixtures.work(iterations:0))
        #expect(iteration.termination == .resourceLimit); #expect(iteration.processedBases == 0)
        let fill=try failure(p,policy:OptimizationFixtures.policy(fill:0))
        if case .capacity(let resource,let required,let limit)=fill.cause { #expect(resource == "factorEntries"); #expect(required == 4); #expect(limit == 0) } else { Issue.record("Expected factor capacity failure") }
        #expect(fill.processedBases == 1); #expect(!fill.failedSupplierWorkUnavailable)
    }
    @Test func cancellationAndExplicitPrecisionAreNotFallbacks() throws {
        let p=try OptimizationFixtures.problem(cost:[1])
        let cancelled=try failure(p,policy:OptimizationFixtures.policy(cancel:{ true }))
        #expect(cancelled.termination == .cancelled); #expect(cancelled.work.operations == 0)
        let precision=try failure(p,policy:OptimizationFixtures.policy(precision:.float32))
        #expect(precision.termination == .unsupportedDomain); #expect(precision.processedBases == 0)
    }
    @Test func actualLUFailureRetainsCauseAndUnavailableConsumption() throws {
        let e=try failure(OptimizationFixtures.problem(cost:[1]),policy:OptimizationFixtures.policy(pivot:10))
        if case .numerical(.singular(let rank,let pivot))=e.cause { #expect(rank == 0); #expect(pivot == 0) } else { Issue.record("Expected actual LU singular failure") }
        #expect(e.phase == .linearSolve); #expect(e.processedBases == 1)
        #expect(e.failedSupplierWorkUnavailable); #expect(e.work.operations > 0); #expect(e.work.iterations == 1)
    }
    @Test func replacedSupplierBudgetStopsOnceAndMarksUnknownConsumption() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Synchronization OS baseline unavailable."); return }
        let supplier=FaultyOptimizationLinearSolver<Double>(.changedBudget)
        let e=try failure(OptimizationFixtures.problem(cost:[1]),service:CompleteConvexOptimizer(linear:supplier))
        if case .invalidSupplierLedger=e.cause {} else { Issue.record("Expected rejected supplier budget") }
        #expect(supplier.invocationCount == 1); #expect(e.failedSupplierWorkUnavailable)
    }
    @Test func knownSuccessfulSupplierWorkIsAbsorbedBeforeInvalidOutput() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Synchronization OS baseline unavailable."); return }
        let p=try OptimizationFixtures.problem(cost:[1])
        let unknown=try failure(p,service:CompleteConvexOptimizer(linear:FaultyOptimizationLinearSolver<Double>(.changedBudget)))
        let supplier=FaultyOptimizationLinearSolver<Double>(.changedDimension)
        let known=try failure(p,service:CompleteConvexOptimizer(linear:supplier))
        if case .invalidSupplierOutput=known.cause {} else { Issue.record("Expected rejected solution dimension") }
        #expect(supplier.invocationCount == 1); #expect(!known.failedSupplierWorkUnavailable)
        #expect(known.work.operations > unknown.work.operations); #expect(known.work.iterations == unknown.work.iterations+1)
    }
    @Test func supplierInternalResidualCannotCertifyOriginalOptimality() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Synchronization OS baseline unavailable."); return }
        let supplier=FaultyOptimizationLinearSolver<Double>(.alteredRightHandSide)
        let e=try failure(OptimizationFixtures.problem(cost:[1]),service:CompleteConvexOptimizer(linear:supplier))
        #expect(e.termination == .nonconverged); #expect(e.isPhaseOne)
        if case .certificateRejected=e.cause {} else { Issue.record("Expected rejected original certificate") }
        #expect(!e.failedSupplierWorkUnavailable); #expect(supplier.invocationCount > 1)
    }
    @Test func originalAndPhaseOneFailuresHaveDistinctResidualAuthority() throws {
        let p=try OptimizationFixtures.problem(cost:[0],inequality:[[1]],ineqRHS:[-1])
        let e=try failure(p,policy:OptimizationFixtures.policy(candidates:4))
        #expect(e.termination == .nonconverged); #expect(e.processedBases == 4); #expect(e.isPhaseOne)
    }
    @Test func variableRowAndSparseEntryCapacitiesRejectBeforeEnumeration() throws {
        let p=try OptimizationFixtures.problem(cost:[0,0],inequality:[[1,1]],ineqRHS:[1])
        for policy in [try OptimizationFixtures.policy(variables:1),try OptimizationFixtures.policy(rows:0),try OptimizationFixtures.policy(nonzeros:0)] {
            let e=try failure(p,policy:policy)
            #expect(e.termination == .resourceLimit); #expect(e.processedBases == 0); #expect(e.work.operations == 0)
        }
    }
    @Test func metadataBytesAreChargedBeforeTraversalCompletes() throws {
        let p=try OptimizationFixtures.problem(cost:[1])
        let metadata=try OptimizationMetadata(identity:String(repeating:"x",count:20000),provenance:p.metadata.provenance,
            variableIDs:p.metadata.variableIDs,variableReferences:p.metadata.variableReferences,objectiveReference:p.metadata.objectiveReference)
        let large=ConvexOptimizationProblem(metadata:metadata,linearCost:p.linearCost,lowerBounds:p.lowerBounds,upperBounds:p.upperBounds)
        let e=try failure(large,initialWork:OptimizationFixtures.work(operations:100))
        #expect(e.termination == .resourceLimit); #expect(e.work.operations == 100); #expect(e.processedBases == 0)
    }
    private func failure(_ p: ConvexOptimizationProblem,policy: OptimizationPolicy? = nil,initialWork: NumericalWork? = nil,
        service: any OptimizationSolving = CompleteConvexOptimizer()) throws -> OptimizationFailure {
        var workspace=EnumerationWorkspace(), work=try initialWork ?? OptimizationFixtures.work()
        do {
            _=try service.solve(p,policy:policy ?? OptimizationFixtures.policy(),workspace:&workspace,work:&work)
            Issue.record("Expected typed optimization failure")
            throw OptimizationCause.invalidProblem
        } catch let error as OptimizationFailure {
            #expect(error.work == work)
            return error
        }
    }
}
