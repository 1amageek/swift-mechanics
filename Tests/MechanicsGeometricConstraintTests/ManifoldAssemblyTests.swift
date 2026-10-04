import SwiftMechanics
import Testing
import Foundation

@Suite struct ManifoldAssemblyTests {
    @Test(.timeLimit(.minutes(1))) func perturbedActualFourbarAssemblesUnderTangentMetricAndAllRows() throws {
        let model=try GeometricFixtures.fourbar(),system=try GeometricFixtures.system(model,rows:GeometricFixtures.loopRows(duplicate:true),scales:[2,3,4])
        let state=try GeometricFixtures.state(model.descriptor.initialState,q:[0.65,0.57,-0.52]);var work=try GeometricFixtures.work()
        let assembler:any ManifoldConstraintProjecting=TangentManifoldAssembler()
        let result=try assembler.assemble(system,initial:state,policy:GeometricFixtures.policy(3),work:&work)
        let q=result.state.q,x=cos(q[0])+2*cos(q[0]+q[2])-2-cos(q[1]),y=sin(q[0])+2*sin(q[0]+q[2])-sin(q[1])
        #expect(abs(x) < 2e-9);#expect(abs(y) < 2e-9)
        #expect(result.rank.rank == 2);#expect(result.rank.reactionNullity == 4);#expect(!result.rank.reactionsUnique)
        #expect(result.geometry.velocity.rowIDs == [11,12,13,21,22,23])
        #expect(result.pathCorrection > 0);#expect(result.iterations > 0);#expect(result.state.v == state.v);#expect(result.state.time == state.time)
        #expect(result.work == work);#expect(result.correctionMetadata.hasPrefix("tangent-path-v1"))
    }
    @Test func mixedQuaternionAssemblyPreservesManifoldAndActualRows() throws {
        let model=try GeometricFixtures.mixed()
        let a=try GeometricFrameEndpoint(body:GeometricFixtures.id(.body,"sphere"),frame:GeometricFixtures.id(.frame,"sphere"),point:.unitX,axis:.unitX)
        let b=try GeometricFrameEndpoint(body:GeometricFixtures.id(.body,"free"),frame:GeometricFixtures.id(.frame,"free"),point:.unitX,axis:.unitX)
        let rows=[try GeometricRelation(kind:.coincidence,rowIDs:[1,2,3],first:a,second:b,target:GeometricAnalyticTarget(),scale:1),
                  try GeometricRelation(kind:.alignedAxes,rowIDs:[4,5],first:a,second:b,target:GeometricAnalyticTarget(),scale:1)]
        let system=try GeometricFixtures.system(model,rows:rows)
        let free=try GeometricFixtures.entry(model,"f")
        var q=model.descriptor.initialState.q;q[free.positions.start]=0.08;q[free.positions.start+1] = -0.04
        q[free.positions.start+3]=cos(0.05);q[free.positions.start+6]=sin(0.05)
        let state=try GeometricFixtures.state(model.descriptor.initialState,q:q);var work=try GeometricFixtures.work()
        let result=try TangentManifoldAssembler().assemble(system,initial:state,policy:GeometricFixtures.policy(15),work:&work)
        #expect(result.originalResidual < 1e-9);#expect(result.rank.rank == 5)
        for start in try GeometricFixtures.quaternionStarts(model) { #expect(abs(result.state.q[start..<start+4].reduce(0){$0+$1*$1}-1) < 1e-12) }
        #expect(result.state.v == state.v)
        let first=try result.geometry.snapshot.body(a.body).motion.pose.rotation.rotating(a.axis)
        let second=try result.geometry.snapshot.body(b.body).motion.pose.rotation.rotating(b.axis)
        let physicalCross=try first.cross(second)
        #expect(try physicalCross.magnitude() < 2e-9)
        #expect(try first.dot(second) > 1-1e-10)
        #expect(result.geometry.velocity.rowIDs == [1,2,3,4,5]);#expect(result.rank.reactionNullity == 0)
    }
    @Test func contradictionForbiddenRedundancyToggleAndCorrectionBoundFail() throws {
        let model=try GeometricFixtures.fourbar(),base=try GeometricFixtures.loopRows(),other=try GeometricFixtures.loopRows(target:GeometricAnalyticTarget(value:Vector3(0.1,0,0)))
        let conflicting=try GeometricRelation(kind:.coincidence,rowIDs:[21,22,23],first:other[0].first,second:other[0].second,target:other[0].target,scale:2)
        let contradiction=try GeometricFixtures.system(model,rows:base+[conflicting]);var work=try GeometricFixtures.work()
        #expect(throws:ManifoldProjectionFailure.self) { try TangentManifoldAssembler().assemble(contradiction,initial:model.descriptor.initialState,policy:GeometricFixtures.policy(3,iterations:4),work:&work) }
        let duplicate=try GeometricFixtures.system(model,rows:GeometricFixtures.loopRows(duplicate:true));work=try GeometricFixtures.work()
        let independentPolicy=try GeometricFixtures.policy(3,rank:.requireIndependentRows)
        do throws(ManifoldProjectionFailure) { _=try TangentManifoldAssembler().assemble(duplicate,initial:model.descriptor.initialState,policy:independentPolicy,work:&work);Issue.record("Ambiguity accepted") }
        catch { if case .constraint(.rankAmbiguity)=error.cause {} else { Issue.record("Wrong ambiguity failure") } }
        let normal=try GeometricFixtures.system(model,rows:base),perturbed=try GeometricFixtures.state(model.descriptor.initialState,q:[0.65,0.57,-0.52]);work=try GeometricFixtures.work()
        let correctionPolicy=try GeometricFixtures.policy(3,limit:1e-6)
        do throws(ManifoldProjectionFailure) { _=try TangentManifoldAssembler().assemble(normal,initial:perturbed,policy:correctionPolicy,work:&work);Issue.record("Correction accepted") }
        catch { if case .correctionExceeded=error.cause {} else { Issue.record("Wrong correction failure") };#expect(error.lastPosition == perturbed.q) }
        let toggleModel=try GeometricFixtures.fourbar(angle:0,nonidentityFrame:false),toggle=try GeometricFixtures.system(toggleModel,rows:GeometricFixtures.loopRows());work=try GeometricFixtures.work()
        let accepted=try TangentManifoldAssembler().assemble(toggle,initial:toggleModel.descriptor.initialState,policy:GeometricFixtures.policy(3),work:&work)
        #expect(accepted.rank.rank == 1);#expect(accepted.rank.reactionNullity == 2)
        work=try GeometricFixtures.work()
        let impossible=try GeometricFixtures.state(toggleModel.descriptor.initialState,q:[0,0,0.1])
        #expect(throws:ManifoldProjectionFailure.self) { try TangentManifoldAssembler().assemble(toggle,initial:impossible,policy:GeometricFixtures.policy(3,limit:0.001),work:&work) }
    }
    @Test func invalidExternalQuaternionAndCapacitiesAreRejected() throws {
        let model=try GeometricFixtures.mixed(),a=try GeometricFrameEndpoint(body:GeometricFixtures.id(.body,"sphere"),frame:GeometricFixtures.id(.frame,"sphere")),b=try GeometricFrameEndpoint(body:GeometricFixtures.id(.body,"free"),frame:GeometricFixtures.id(.frame,"free"))
        let rows=[try GeometricRelation(kind:.coincidence,rowIDs:[1,2,3],first:a,second:b,target:GeometricAnalyticTarget(),scale:1)]
        let system=try GeometricFixtures.system(model,rows:rows),sphere=try GeometricFixtures.entry(model,"s");var q=model.descriptor.initialState.q;q[sphere.positions.start]=1.01
        let state=try GeometricFixtures.state(model.descriptor.initialState,q:q);var work=try GeometricFixtures.work()
        let chartPolicy=try GeometricFixtures.policy(15)
        do throws(ManifoldProjectionFailure) { _=try TangentManifoldAssembler().assemble(system,initial:state,policy:chartPolicy,work:&work);Issue.record("Off-norm external state accepted") }
        catch { if case .invalidChart=error.cause {} else { Issue.record("Wrong chart failure") };#expect(error.lastPosition == q) }
        #expect(throws:GeometricConstraintError.self) { try GeometricFixtures.system(model,rows:rows,metadata:10) }
        let valid=model.descriptor.initialState;work=try GeometricFixtures.work(storage:1)
        #expect(throws:ManifoldProjectionFailure.self) { try TangentManifoldAssembler().assemble(system,initial:valid,policy:GeometricFixtures.policy(15),work:&work) }
        work=try GeometricFixtures.work(operations:1)
        #expect(throws:GeometricConstraintError.self) { try GeometricRelationEvaluator().evaluate(system,state:valid,policy:GeometricFixtures.evaluation(),work:&work) }
    }
    @Test func successfulFailedResetStaleSourceLateCancellationAndUnknownWorkKeepPrefix() throws {
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) {
            let model=try GeometricFixtures.fourbar(),system=try GeometricFixtures.system(model,rows:GeometricFixtures.loopRows())
            for mode in [GeometricFaultSupplier.Mode.resetSuccess,.resetFailure,.wrongSource,.cancelled] {
                let supplier=GeometricFaultSupplier(mode);var work=try GeometricFixtures.work()
                let policy=try GeometricFixtures.policy(3,cancelled:{supplier.cancellation.withLock{$0}})
                do throws(ManifoldProjectionFailure) { _=try TangentManifoldAssembler(evaluator:supplier).assemble(system,initial:model.descriptor.initialState,policy:policy,work:&work);Issue.record("Fault accepted") }
                catch {
                    #expect(error.work == work);#expect(work.operations > 0);#expect(error.lastPosition == model.descriptor.initialState.q)
                    switch mode {
                    case .resetSuccess,.resetFailure:if case .supplierLedgerReplaced=error.cause {} else { Issue.record("Reset not detected") };#expect(error.failedSupplierWorkUnavailable)
                    case .wrongSource:if case .staleSource=error.cause {} else { Issue.record("Source not rejected") }
                    case .cancelled:if case .cancelled=error.cause {} else { Issue.record("Late cancellation not rejected") }
                    }
                }
            }
            var work=try GeometricFixtures.work();let state=try GeometricFixtures.state(model.descriptor.initialState,q:[0.65,0.57,-0.52])
            let linearPolicy=try GeometricFixtures.policy(3)
            do throws(ManifoldProjectionFailure) { _=try TangentManifoldAssembler(linear:GeometricFailureLinear()).assemble(system,initial:state,policy:linearPolicy,work:&work);Issue.record("Unknown linear work accepted") }
            catch { #expect(error.failedSupplierWorkUnavailable);#expect(error.work == work);#expect(error.lastPosition == state.q) }
        }
    }
}
