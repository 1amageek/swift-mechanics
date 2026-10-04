import SwiftMechanics
import Testing

@Suite struct GeometricEvolutionFailureTests {
    @Test(.timeLimit(.minutes(1))) func lateGeometryResetAndCancelKeepCompleteAcceptedPrefix() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try GeometricEvolutionFourBar(),system=try GeometricEvolutionFixtures.fourbarSystem(fixture)
            for fault in [GeometricEvolutionSupplier.Fault.resetSuccess,.resetFailure,.cancel] {
                let equation=try GeometricEvolutionFixtures.equation(system,evaluator:GeometricEvolutionSupplier(fault:fault))
                let (session,continuation)=try NonlinearMechanismFixtures.session(equation,step:0.05);defer { _=session.shutdown() }
                let evolution=ProjectedNonlinearMechanismEvolution()
                let prefix=try evolution.advance(session,equations:equation,continuation:continuation,to:0.05).accepted
                do throws(NonlinearMechanismFailure) { _=try evolution.advance(session,equations:equation,continuation:continuation,to:0.1);Issue.record("Geometry supplier fault published") }
                catch {
                    #expect(error.lastAccepted == prefix);#expect(error.work.supplierArithmeticCharged > 0);#expect(error.rejectedTrials == 0)
                    if case .cancel=fault { #expect(error.cause.code == .cancelled);#expect(!error.work.failedSupplierWorkUnavailable) }
                    else { #expect(error.cause.code == .invalidOwnerAccess);#expect(error.work.failedSupplierWorkUnavailable) }
                }
                #expect(session.snapshot() == prefix)
                _=try continuation.associatedHistory(try #require(prefix.checkpoint.contributors.first),physical:prefix.checkpoint.physical,equations:equation)
            }
        }
    }
    @Test(.timeLimit(.minutes(1))) func originalGeometryWrongSourceAndActualWrongPhysicalInputCannotPublish() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try GeometricEvolutionFourBar(),system=try GeometricEvolutionFixtures.fourbarSystem(fixture)
            let equation=try GeometricEvolutionFixtures.equation(system,evaluator:GeometricEvolutionSupplier(fault:.source))
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation);defer { _=session.shutdown() }
            let prefix=session.snapshot()
            do throws(NonlinearMechanismFailure) { _=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.01);Issue.record("Wrong geometry source accepted") }
            catch { #expect(error.lastAccepted == prefix);#expect(error.cause.code == .invalidState);#expect(error.work.supplierArithmeticCharged > 0) }
            #expect(session.snapshot() == prefix)
            let model=try NonlinearMechanismFixtures.model(q:[1,0],v:[0,0])
            let a=try GeometricFrameEndpoint(body:NonlinearMechanismFixtures.id(.body,"mass"),frame:NonlinearMechanismFixtures.id(.frame,"mass-frame"))
            let b=try GeometricFrameEndpoint(body:NonlinearMechanismFixtures.id(.body,"root"),frame:NonlinearMechanismFixtures.id(.frame,"root-frame"))
            let relation=try GeometricRelation(kind:.distance,rowIDs:[1],first:a,second:b,target:GeometricAnalyticTarget(value:Vector3(1,0,0)),scale:1)
            let circle=try GeometricEvolutionFixtures.system(model,relations:[relation])
            for change in [WrongSourceKernel.Change.pose,.inertia,.load] {
                let wrong=try GeometricEvolutionFixtures.equation(circle,kernel:WrongSourceKernel(model:model,change:change))
                let (bad,history)=try NonlinearMechanismFixtures.session(wrong);defer { _=bad.shutdown() };let before=bad.snapshot()
                do throws(NonlinearMechanismFailure) { _=try ProjectedNonlinearMechanismEvolution().advance(bad,equations:wrong,continuation:history,to:0.01);Issue.record("Wrong physical source accepted") }
                catch { #expect(error.lastAccepted == before);#expect(error.cause.message == "Rigid supplier result source differs.") }
                #expect(bad.snapshot() == before)
            }
        }
    }
    @Test(.timeLimit(.minutes(1))) func strictInitialQuaternionAndBoundedStageCorrectionAreDistinct() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try GeometricEvolutionFixtures.mixed(),system=try GeometricEvolutionFixtures.mixedSystem(model)
            let equation=try GeometricEvolutionFixtures.equation(system)
            let limited=try GeometricEvolutionFixtures.equation(system,chartLimit:1e-5)
            let (session,_)=try NonlinearMechanismFixtures.session(equation);defer { _=session.shutdown() }
            let prefix=session.snapshot(),capture=NonlinearTestCapture()
            var altered=model.descriptor.initialState.q;altered[3]=1.001
            let point=altered+model.descriptor.initialState.v
            for stage in [false,true] {
                do throws(RuntimeFailure) {
                    _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                        var work=NumericalWork(budget:equation.publicationBudget)
                        if stage { _=try limited.consistent(time:0,point:point,work:&work,control:control) }
                        else { try equation.validateInitial(time:0,point:point,work:&work,control:control) }
                        return .accept
                    }
                    Issue.record("Unbounded or external invalid chart accepted")
                } catch { #expect(error.code == .invalidState) }
                #expect(session.snapshot() == prefix)
            }
            _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                var work=NumericalWork(budget:equation.publicationBudget)
                capture.store(try equation.consistent(time:0,point:point,work:&work,control:control));return .reject
            }
            let corrected=try #require(capture.read())
            let chartCorrection=try #require(corrected.stageChartCorrection)
            #expect(abs(chartCorrection-0.001) < 1e-12)
            #expect(corrected.point[..<model.tree.layout.positionCount].elementsEqual(model.descriptor.initialState.q))
            #expect(session.snapshot() == prefix)
        }
    }
    @Test(.timeLimit(.minutes(1))) func exactEndpointFailureRollsBackPhysicalHistoryAndRandom() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try GeometricEvolutionFourBar(),system=try GeometricEvolutionFixtures.fourbarSystem(fixture)
            let equation=try GeometricEvolutionFixtures.equation(system)
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation);defer { _=session.shutdown() }
            let prefix=session.snapshot(),p=fixture.model.tree.layout.positionCount,n=fixture.model.tree.layout.velocityCount
            for ordinary in [false,true] {
                do throws(RuntimeFailure) {
                    _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                        _=try trial.nextRandom()
                        var work=NumericalWork(budget:equation.publicationBudget),point=prefix.checkpoint.physical.q+prefix.checkpoint.physical.v
                        var derivative=[Double](repeating:0,count:p+n)
                        try equation.derivative(time:0,point:point,into:&derivative,work:&work,control:control)
                        point[fixture.couplerIndex]+=0.001
                        if ordinary { try equation.write(point:point,derivative:derivative,time:0,trial:&trial) }
                        else { try equation.writeAccepted(point:point,derivative:derivative,time:0,trial:&trial,work:&work,control:control) }
                        return .accept
                    }
                    Issue.record("Inconsistent exact endpoint accepted")
                } catch { #expect(error.code == .invalidState) }
                #expect(session.snapshot() == prefix)
                _=try continuation.associatedHistory(try #require(prefix.checkpoint.contributors.first),physical:prefix.checkpoint.physical,equations:equation)
            }
        }
    }
    @Test(.timeLimit(.minutes(1))) func immutableMetadataBindsPhysicalDriveAndChartCorrectionPolicy() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try GeometricEvolutionFourBar(),system=try GeometricEvolutionFixtures.fourbarSystem(fixture)
            let base=try GeometricEvolutionFixtures.equation(system),driven=try GeometricEvolutionFixtures.equation(system,drive:[0.01,0,0])
            let limit=try GeometricEvolutionFixtures.equation(system,chartLimit:0.001)
            #expect(base.descriptor != driven.descriptor);#expect(base.descriptor != limit.descriptor)
            let (session,continuation)=try NonlinearMechanismFixtures.session(base);defer { _=session.shutdown() };let prefix=session.snapshot()
            do throws(NonlinearMechanismFailure) { _=try ProjectedNonlinearMechanismEvolution().advance(session,equations:driven,continuation:continuation,to:0.01);Issue.record("Wrong bound drive accepted") }
            catch { #expect(error.lastAccepted == prefix);#expect(error.cause.code == .invalidInput) }
            #expect(session.snapshot() == prefix)
        }
    }
    @Test(.timeLimit(.minutes(1))) func genuineDifferentQuaternionAccelerationSourceCannotChangeQdot() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try NonlinearMechanismFixtures.model(q:[1,0,0,0],v:[0,0,1],spherical:true)
            let a=try GeometricFrameEndpoint(body:NonlinearMechanismFixtures.id(.body,"mass"),frame:NonlinearMechanismFixtures.id(.frame,"mass-frame"),axis:.unitZ)
            let b=try GeometricFrameEndpoint(body:NonlinearMechanismFixtures.id(.body,"root"),frame:NonlinearMechanismFixtures.id(.frame,"root-frame"),axis:.unitZ)
            let relation=try GeometricRelation(kind:.alignedAxes,rowIDs:[1,2],first:a,second:b,target:GeometricAnalyticTarget(),scale:1)
            let equation=try GeometricEvolutionFixtures.equation(GeometricEvolutionFixtures.system(model,relations:[relation]),solver:WrongSourceMechanismSolver(model:model))
            let (session,continuation)=try NonlinearMechanismFixtures.session(equation);defer { _=session.shutdown() };let prefix=session.snapshot()
            do throws(NonlinearMechanismFailure) { _=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.01);Issue.record("Wrong acceleration source accepted") }
            catch { #expect(error.cause.message == "Mechanism supplier source/result differs.");#expect(error.lastAccepted == prefix);#expect(error.work.supplierArithmeticCharged > 0) }
            #expect(session.snapshot() == prefix)
        }
    }

}
