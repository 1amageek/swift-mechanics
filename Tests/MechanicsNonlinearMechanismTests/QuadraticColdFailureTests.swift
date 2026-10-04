import SwiftMechanics
import Testing

@Suite struct QuadraticColdFailureTests {
    @Test(.timeLimit(.minutes(1))) func coldSolverResetRetainsOtherExecutedPrefixesAndNoPhysicalEvidence() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let release=try QuadraticColdFixture().release()
            for fault in [QuadraticColdFaultSolver.Fault.resetSuccess,.resetFailure,.unknown,.knownFailure,.lateCancellation] {
                let solver=QuadraticColdFaultSolver(fault)
                let equation=try QuadraticColdFixture.equation(release.target,target:true,solver:solver,isCancelled:{solver.isCancelled()})
                var work=try QuadraticColdFixture.work()
                do throws(RuntimeFailure) {
                    _=try ReferenceNonlinearSubtreeAccelerationPreparer().prepare(release:release,equations:equation,work:&work)
                    Issue.record("Faulty cold supplier issued immutable target evidence")
                } catch {
                    switch fault {
                    case .resetSuccess,.resetFailure: #expect(error.code == .invalidOwnerAccess);#expect(error.failedSupplierWorkUnavailable)
                    case .unknown: #expect(error.code == .invalidState);#expect(error.failedSupplierWorkUnavailable)
                    case .knownFailure: #expect(error.code == .invalidState);#expect(!error.failedSupplierWorkUnavailable)
                    case .lateCancellation: #expect(error.code == .cancelled);#expect(!error.failedSupplierWorkUnavailable)
                    }
                }
                let evidence=try #require(solver.evidence())
                #expect(evidence.seeds == 4);#expect(evidence.aggregateAllowance < work.budget.arithmeticOperations)
                #expect(work.operations >= evidence.knownPrefix);#expect(work.operations <= work.budget.arithmeticOperations)
                #expect(release.incomingPhysical == release.target.descriptor.initialState)
            }
        }
    }
    @Test(.timeLimit(.minutes(1))) func targetMismatchAndScalarCapacityRefuseBeforeSolverEntry() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try QuadraticColdFixture(),release=try fixture.release(),wrong=try QuadraticColdFixture.equation(fixture.model)
            var work=try QuadraticColdFixture.work()
            do throws(RuntimeFailure) { _=try ReferenceNonlinearSubtreeAccelerationPreparer().prepare(release:release,equations:wrong,work:&work);Issue.record("Wrong target equation admitted") }
            catch { #expect(error.code == .incompatibleModel) }
            let admission=try QuadraticColdFixture.admission()
            do throws(MechanismError) {
                _=try NonlinearMechanismEquation(identity:wrong.descriptor.identity,sourceBoundModel:wrong.model,constraints:wrong.constraints,
                    velocityLayout:wrong.velocityLayout,drive:wrong.drive,policy:wrong.policy,projection:wrong.projection,
                    admission:admission,maximumIdentityBytes:wrong.descriptor.chart.utf8.count-1)
                Issue.record("Original source signature exceeded caller byte bound")
            } catch { if case .capacityExceeded=error {} else { Issue.record("Unexpected source signature error") } }
            let solver=QuadraticColdFaultSolver(.unknown),equation=try QuadraticColdFixture.equation(release.target,target:true,solver:solver)
            var limited=NumericalWork(budget:try NumericalBudget(scalarStorage:1,arithmeticOperations:100_000_000,iterations:1000))
            do throws(RuntimeFailure) { _=try ReferenceNonlinearSubtreeAccelerationPreparer().prepare(release:release,equations:equation,work:&limited);Issue.record("Unadmitted scalar envelope entered callback") }
            catch { #expect(error.code == .capacityExceeded) }
            #expect(solver.evidence() == nil);#expect(limited.operations == 0)
        }
    }
    @Test(.timeLimit(.minutes(1))) func actualLateEvaluatorResetCancelAndFailedRestartLeaveBytesAndRandomUnchanged() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try QuadraticColdFixture()
            for evaluator in [NonlinearLedgerSupplier(fails:false),NonlinearLedgerSupplier(fails:true),NonlinearLedgerSupplier(fails:true,resets:false)] {
                let equation=try QuadraticColdFixture.equation(fixture.model,evaluator:evaluator)
                let (session,continuation)=try QuadraticColdFixture.session(equation);defer { _=session.shutdown() }
                let prefix=session.snapshot(),codec=NativeRuntimeCheckpointCodec(),before=try session.checkpoint(codec:codec)
                do throws(RuntimeFailure) {
                    _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                        _=try trial.nextRandom();try trial.setTime(0.1)
                        try trial.replaceContributor(continuation.record(acceptedTime:0.1,point:prefix.checkpoint.physical.q+prefix.checkpoint.physical.v,nextStep:0.01,acceptedSteps:1,normalizedError:nil))
                        return .accept
                    }
                    Issue.record("Faulty quadratic cold evaluator published")
                } catch {
                    #expect(error.failedSupplierWorkUnavailable == evaluator.resets)
                    #expect(error.code == (evaluator.resets ? .invalidOwnerAccess : .cancelled))
                }
                #expect(session.snapshot() == prefix);#expect(try session.checkpoint(codec:codec) == before)
                let physical=try KinematicState(revision:1,time:0.1,q:prefix.checkpoint.physical.q,v:prefix.checkpoint.physical.v,acceleration:prefix.checkpoint.physical.acceleration)
                let record=try continuation.record(acceptedTime:0.1,point:physical.q+physical.v,nextStep:0.01,acceptedSteps:1,normalizedError:nil)
                let saved=try RuntimeCheckpoint(model:fixture.model.stamp,continuation:prefix.checkpoint.continuation,physical:physical,contributors:[record],random:prefix.checkpoint.random,acceptedSteps:1)
                do throws(RuntimeFailure) { _=try session.restart(codec.encode(saved,capacity:session.configuration.capacity),codec:codec);Issue.record("Faulty cold restore published") }
                catch { #expect(error.failedSupplierWorkUnavailable == evaluator.resets) }
                #expect(try session.checkpoint(codec:codec) == before)
            }
        }
    }
}
