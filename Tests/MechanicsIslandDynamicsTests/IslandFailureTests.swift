import Testing
import SwiftMechanics

@Suite internal struct IslandFailureTests {
    @Test(arguments:[0,1,2,3]) func assemblySourceAndLedgerGuard(_ mode:Int) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let source=try IslandFixtures.model(),policy=try IslandFixtures.policy()
        let fault=IslandEquationFault(mode == 0 ? .numericalReset : mode == 1 ? .loadReset : mode == 2 ? .cancelReset : .wrongSource)
        var work=try IslandFixtures.work();let constraints=try IslandFixtures.constraints(source)
        do throws(StationaryIslandFailure) {
            _=try ReferenceStationaryIslandPreparer(equations:fault).prepare(source:source,constraints:constraints,drive:[0,0,0],policy:policy,work:&work)
            Issue.record("Invalid supplier accepted")
        } catch {
            #expect(fault.count == 1);#expect(error.knownWork.numerical == work.numerical)
            #expect(error.knownWork.loads.consumed == work.loads.consumed);#expect(work.numerical.operations > 0);#expect(work.loads.consumed > 0)
            if mode == 2 { if case .dynamics(.cancelled)=error.reason {} else { Issue.record("Cancellation not preserved") } }
            else if mode < 2 { if case .supplierLedgerFailure=error.reason {} else { Issue.record("Reset not refused") } }
            else { if case .sourceMismatch=error.reason {} else { Issue.record("Source mismatch not refused") } }
            #expect(error.failedSupplierWorkUnavailable == (mode < 3))
        }
    }
    @Test(arguments:[false,true]) func freeForwardKnownPrefix(_ fail:Bool) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let program=try IslandFixtures.program(),island=try #require(program.islands.first(where:{$0.constraints == nil}))
        var work=try IslandFixtures.work();let solver=ReferenceStationaryIslandDynamics(dynamics:IslandForwardFault(fail:fail))
        do throws(StationaryIslandFailure) { _=try solver.motion(program:program,islandID:island.id,physical:program.source.descriptor.initialState,work:&work);Issue.record("Reset accepted") }
        catch { #expect(error.failedSupplierWorkUnavailable);#expect(error.knownWork.numerical == work.numerical);#expect(work.numerical.operations > 0)
            if fail { if case .dynamics(.cancelled)=error.reason {} else { Issue.record("Lost original cancellation") } }
            else { if case .supplierLedgerFailure=error.reason {} else { Issue.record("Wrong reset failure") } }
        }
    }
    @Test(arguments:[false,true]) func evaluatorKnownPrefix(_ fail:Bool) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let program=try IslandFixtures.program(),island=try #require(program.islands.first(where:{$0.constraints != nil}))
        var work=try IslandFixtures.work();let solver=ReferenceStationaryIslandDynamics(evaluator:IslandEvaluationFault(fail:fail))
        do throws(StationaryIslandFailure) { _=try solver.motion(program:program,islandID:island.id,physical:program.source.descriptor.initialState,work:&work);Issue.record("Reset accepted") }
        catch { #expect(error.failedSupplierWorkUnavailable);#expect(error.knownWork.numerical == work.numerical)
            if fail { if case .constraint(.cancelled)=error.reason {} else { Issue.record("Lost original cancellation") } }
        }
    }
    @Test(arguments:[0,1,2,3],[false,true]) func allFourConstrainedSupplierLedgers(_ index:Int,_ fail:Bool) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let program=try IslandFixtures.program(),island=try #require(program.islands.first(where:{$0.constraints != nil}))
        var work=try IslandFixtures.work();let solver=ReferenceStationaryIslandDynamics(solver:IslandSolverFault(index:index,fail:fail))
        do throws(StationaryIslandFailure) { _=try solver.motion(program:program,islandID:island.id,physical:program.source.descriptor.initialState,work:&work);Issue.record("Reset accepted") }
        catch { #expect(error.failedSupplierWorkUnavailable);#expect(error.knownWork.numerical == work.numerical);#expect(work.numerical.operations > 0)
            if fail { if case .mechanism(.cancelled)=error.reason {} else { Issue.record("Lost original cancellation") } }
            else { if case .supplierLedgerFailure=error.reason {} else { Issue.record("Wrong reset failure") } }
        }
    }
    @Test(arguments:[0,1,2,3]) func boundedAdmissionBeforeSuppliers(_ variant:Int) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let source=try IslandFixtures.model(),fault=IslandEquationFault(.numericalReset),token=HybridCancellation()
        let policy=try IslandFixtures.policy(islands:variant == 0 ? 1 : 3,calls:variant == 1 ? 1 : 3,signature:variant == 2 ? 8 : 65536,token:token)
        let constraints=try IslandFixtures.constraints(source)
        if variant == 3 { token.cancel() };var work=try IslandFixtures.work()
        do throws(StationaryIslandFailure) { _=try ReferenceStationaryIslandPreparer(equations:fault).prepare(source:source,constraints:constraints,drive:[0,0,0],policy:policy,work:&work);Issue.record("Bound admitted") }
        catch { #expect(fault.count == 0);#expect(work.compilationCalls == 0);#expect(error.knownWork.compilationCalls == 0) }
    }
    @Test(arguments:[0,1,2]) func unsupportedRowsAndRankRefusal(_ variant:Int) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let source=try IslandFixtures.model(),original=try IslandFixtures.constraints(source),row=original.rows[0]
        let rows:[QuadraticConstraint]
        if variant == 0 { rows=[QuadraticConstraint(id:7,constant:0,linear:[1,1,0],hessian:[1,0,0,0,0,0,0,0,0],timeLinear:0,timeQuadratic:0,mixedTime:[0,0,0])] }
        else if variant == 1 { rows=[QuadraticConstraint(id:7,constant:0,linear:[0,0,0],hessian:[Double](repeating:0,count:9),timeLinear:0,timeQuadratic:0,mixedTime:[0,0,0])] }
        else { rows=[row,QuadraticConstraint(id:8,constant:row.constant,linear:row.linear,hessian:row.hessian,timeLinear:0,timeQuadratic:0,mixedTime:row.mixedTime)] }
        let constraints=try QuadraticConstraintSystem(layout:original.layout,rows:rows,minimumPosition:original.minimumPosition,maximumPosition:original.maximumPosition,minimumTime:0,maximumTime:10)
        var work=try IslandFixtures.work();let policy=try IslandFixtures.policy();let program:StationaryIslandProgram
        do throws(StationaryIslandFailure) { program=try ReferenceStationaryIslandPreparer().prepare(source:source,constraints:constraints,drive:[0,0,0],policy:policy,work:&work) }
        catch { if variant < 2 { #expect(work.compilationCalls == 0);return };throw error }
        do throws(StationaryIslandFailure) { _=try ReferenceStationaryIslandDynamics().motion(program:program,islandID:program.islands[0].id,physical:source.descriptor.initialState,work:&work);Issue.record("Ambiguous rank admitted") }
        catch { if case .rankAmbiguity=error.reason {} else { Issue.record("Wrong rank refusal") } }
    }
    @Test func opaqueCompilationReceiptNoRetry() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let source=try IslandFixtures.model(),constraints=try IslandFixtures.constraints(source),policy=try IslandFixtures.policy()
        var work=try IslandFixtures.work()
        do throws(StationaryIslandFailure) {
            _=try ReferenceStationaryIslandPreparer(compiler:IslandCompilerFault()).prepare(source:source,constraints:constraints,drive:[0,0,0],policy:policy,work:&work)
            Issue.record("Opaque failed compiler accepted")
        } catch {
            if case .compilation(let original)=error.reason { #expect(!original.diagnostics.isEmpty) }
            else { Issue.record("Original compilation failure lost") }
            #expect(error.failedSupplierWorkUnavailable);#expect(work.compilationCalls == 1)
            #expect(error.knownWork.compilationCalls == 1);#expect(error.knownWork.numerical == work.numerical)
        }
    }
    @Test func workAdmissionBeforePhysicalCallback() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let program=try IslandFixtures.program(),fault=IslandEquationFault(.numericalReset)
        var work=try IslandFixtures.work(operations:0,storage:0)
        do throws(StationaryIslandFailure) {
            _=try ReferenceStationaryIslandDynamics(equations:fault).motion(program:program,islandID:program.islands[0].id,physical:program.source.descriptor.initialState,work:&work)
            Issue.record("Capacity exhausted work admitted")
        } catch { #expect(fault.count == 0);#expect(work.numerical.operations == 0);#expect(work.loads.consumed == 0) }
    }
    @Test func movingDescendantCannotAuthorizePartition() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let source=try IslandFixtures.model(descendant:true),constraints=try IslandFixtures.constraints(source),policy=try IslandFixtures.policy()
        var work=try IslandFixtures.work()
        do throws(StationaryIslandFailure) {
            _=try ReferenceStationaryIslandPreparer().prepare(source:source,constraints:constraints,drive:[0,0,0],policy:policy,work:&work)
            Issue.record("Moving shared branch admitted as independent")
        } catch { if case .unsupportedDomain=error.reason {} else { Issue.record("Wrong structural refusal") };#expect(work.compilationCalls == 0) }
    }
    @Test(arguments:[1,2]) func nestedOriginalCancellationRemainsPrimary(_ variant:Int) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let program=try IslandFixtures.program(),island=try #require(program.islands.first(where:{$0.constraints == nil}))
        var work=try IslandFixtures.work()
        do throws(StationaryIslandFailure) {
            _=try ReferenceStationaryIslandDynamics(dynamics:IslandForwardFault(fail:true,nested:variant)).motion(program:program,islandID:island.id,physical:program.source.descriptor.initialState,work:&work)
            Issue.record("Reset/cancellation accepted")
        } catch {
            if variant == 1 { if case .dynamics(.loads(.cancelled))=error.reason {} else { Issue.record("Original nested load cancellation lost") } }
            else { if case .dynamics(.numerical(.cancelled,_))=error.reason {} else { Issue.record("Original nested numerical cancellation lost") } }
            #expect(error.failedSupplierWorkUnavailable);#expect(error.supplierFailure != nil);#expect(error.knownWork.failedSupplierWorkUnavailable);#expect(work.failedSupplierWorkUnavailable);#expect(error.knownWork.numerical == work.numerical)
        }
    }
    @Test func originalConstraintUnknownFailureIsReported() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let program=try IslandFixtures.program(),island=try #require(program.islands.first(where:{$0.constraints != nil}))
        var work=try IslandFixtures.work()
        do throws(StationaryIslandFailure) {
            _=try ReferenceStationaryIslandDynamics(evaluator:IslandEvaluationFault(fail:true,opaque:true)).motion(program:program,islandID:island.id,physical:program.source.descriptor.initialState,work:&work)
            Issue.record("Opaque failed evaluation accepted")
        } catch {
            if case .constraint(.linear(.cancelled,true))=error.reason {} else { Issue.record("Original typed constraint cause lost") }
            #expect(error.failedSupplierWorkUnavailable);#expect(error.knownWork.failedSupplierWorkUnavailable);#expect(work.failedSupplierWorkUnavailable);#expect(error.knownWork.numerical == work.numerical)
        }
    }

}
