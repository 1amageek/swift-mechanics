import Testing
import Foundation
import MechanicsCore
import MechanicsModel
import MechanicsJoints
import MechanicsNumerics
import MechanicsLoads
import MechanicsDynamics
import MechanicsDerivatives
@Suite struct DerivativeFailureTests {
    private func providerInput(_ behavior: SpringForceProvider.Behavior) throws -> MechanicalDerivativeInput {
        let x=try DerivativeFixtures.pendulum()
        return MechanicalDerivativeInput(tree:x.tree,state:x.state,inertias:x.inertias,gravity:x.gravity,drive:x.drive,
            forceProvider:SpringForceProvider(behavior:behavior),parameters:[3],parameterIDs:[101],parameterDimensions:[PhysicalDimension(length:2,mass:1,angle:-2)])
    }
    @Test func requiredCallbackParameterAndOriginalForceEvidence() throws {
        let x=try providerInput(.valid), d=DerivativeFixtures.zero(x,q:[0.2],parameters:[1])
        let out=try DerivativeFixtures.forward(x,d)
        #expect(DerivativeFixtures.close(out.mechanics.totalForce[0],20*0.2*sin(0.4)-1))
        #expect(out.mechanics.parameterIDs == [101]); #expect(out.originalResidual <= out.originalThreshold)
    }
    @Test func derivativeFreePartialResizedAndTypedCallbackFailure() throws {
        for behavior in [SpringForceProvider.Behavior.unavailable,.partial,.resized,.failed] {
            let x=try providerInput(behavior)
            do { _=try DerivativeFixtures.tangent(x,DerivativeFixtures.zero(x)); Issue.record("Expected explicit callback failure") }
            catch let error as DerivativeError {
                switch (behavior,error) {
                case (.unavailable,.derivativeUnavailable), (.partial,.nonFiniteResult), (.resized,.invalidShape), (.failed,.callbackFailure): break
                default: throw error
                }
            }
        }
    }
    @Test func forceCallbackCannotResetAuthoritativeNumericalLedger() throws {
        let x = try providerInput(.resetLedger), original = x.state
        var workspace = MechanicalDerivativeWorkspace(), work = try DerivativeFixtures.work()
        var loads = try DerivativeFixtures.loadWork(), suppliers = try DerivativeSupplierWork(maximumCalls: 1000)
        do {
            _ = try ExactMechanicalDifferentiator().direction(x, direction: DerivativeFixtures.zero(x),
                jointPolicy: DerivativeFixtures.jointPolicy(), admission: DerivativeFixtures.admission(), policy: DerivativeFixtures.policy(),
                workspace: &workspace, loadWork: &loads, supplierWork: &suppliers, work: &work)
            Issue.record("Reset ledger published a derivative result.")
        } catch let error as DerivativeError {
            guard case .invalidSupplierLedger(failedSupplierWorkUnavailable: true) = error else { throw error }
        }
        #expect(work.operations > 0 && x.state == original)
    }
    @Test func callbackMetadataAndCancellationCheckpoint() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Synchronization OS baseline unavailable."); return }
        for cancel in [false,true] {
            let base=try DerivativeFixtures.pendulum(), provider=StatefulBoundaryForceProvider(cancel:cancel)
            let x=MechanicalDerivativeInput(tree:base.tree,state:base.state,inertias:base.inertias,gravity:base.gravity,drive:base.drive,
                forceProvider:provider,parameters:[3],parameterIDs:[101],parameterDimensions:[PhysicalDimension(length:2,mass:1,angle:-2)])
            let original=x.state, normal=try DerivativeFixtures.policy()
            let p=try DerivativePolicy(maximumBodies:normal.maximumBodies,maximumVelocities:normal.maximumVelocities,
                maximumJacobianColumns:normal.maximumJacobianColumns,tolerance:normal.tolerance,residualTolerance:normal.residualTolerance,physicalNeighborhood:normal.physicalNeighborhood,
                inertiaValidation:normal.inertiaValidation,isCancelled:{ cancel && provider.changed.withLock { $0 } })
            var s=MechanicalDerivativeWorkspace(), w=try DerivativeFixtures.work(), l=try DerivativeFixtures.loadWork(), calls=try DerivativeSupplierWork(maximumCalls:1000)
            do { _=try ExactMechanicalDifferentiator().direction(x,direction:DerivativeFixtures.zero(x),jointPolicy:DerivativeFixtures.jointPolicy(),admission:DerivativeFixtures.admission(),
                policy:p,workspace:&s,loadWork:&l,supplierWork:&calls,work:&w); Issue.record("Expected changed metadata or cancellation") }
            catch let error as DerivativeError {
                if cancel { guard case .cancelled=error else { throw error } }
                else { guard case .callbackMetadataChanged=error else { throw error } }
            }
            #expect(x.state == original)
        }
    }
    @Test func staleShapeNonfiniteAndPhysicalNeighborhood() throws {
        let x=try DerivativeFixtures.pendulum(), z=DerivativeFixtures.zero(x)
        let stale=MechanicalDirection(tree:TreeDirection(revision:8,configuration:[0],velocity:[0],acceleration:[0],screwPitch:[0]),inertias:z.inertias,drive:[0])
        do { _=try DerivativeFixtures.tangent(x,stale); Issue.record("Expected stale direction") }
        catch let error as DerivativeError { guard case .staleBinding=error else { throw error } }
        let bad=MechanicalDirection(tree:TreeDirection(revision:7,configuration:[.nan],velocity:[0],acceleration:[0],screwPitch:[0]),inertias:z.inertias,drive:[0])
        do { _=try DerivativeFixtures.tangent(x,bad); Issue.record("Expected nonfinite direction") }
        catch let error as DerivativeError { guard case .invalidInput=error else { throw error } }
        var inertias=z.inertias
        inertias[1]=BodyInertiaDirection(body:x.inertias[1].body,frame:x.inertias[1].frame,mass:3000)
        do { _=try DerivativeFixtures.tangent(x,DerivativeFixtures.zero(x,inertias:inertias)); Issue.record("Expected physical-neighborhood rejection") }
        catch let error as DerivativeError { guard case .model(.invalidMass)=error else { throw error } }
        let shape=MechanicalDirection(tree:z.tree,inertias:z.inertias,drive:[])
        do { _=try DerivativeFixtures.tangent(x,shape); Issue.record("Expected shape rejection") }
        catch let error as DerivativeError { guard case .invalidShape=error else { throw error } }
    }
    @Test func numericalStorageWorkSupplierAndCancelBoundaries() throws {
        let x=try DerivativeFixtures.pendulum(), d=DerivativeFixtures.zero(x)
        for kind in 0..<4 {
            var s=MechanicalDerivativeWorkspace(), w=try DerivativeFixtures.work(storage:kind == 0 ? 0 : 1000000,operations:kind == 1 ? 0 : 10000000),
                l=try DerivativeFixtures.loadWork(), calls=try DerivativeSupplierWork(maximumCalls:kind == 2 ? 0 : 1000)
            do {
                _=try ExactMechanicalDifferentiator().direction(x,direction:d,jointPolicy:DerivativeFixtures.jointPolicy(),admission:DerivativeFixtures.admission(),
                    policy:DerivativeFixtures.policy(cancelled:kind == 3),workspace:&s,loadWork:&l,supplierWork:&calls,work:&w)
                Issue.record("Expected resource or cancellation failure")
            } catch let error as DerivativeError {
                switch (kind,error) {
                case (0,.numerical(.resourceLimit(resource:.scalarStorage,limit:0))),
                     (1,.numerical(.resourceLimit(resource:.arithmeticOperations,limit:0))), (2,.capacityExceeded), (3,.cancelled): break
                default: throw error
                }
            }
        }
    }
    @Test func fullJacobianIterationLimitAndSupplierSingularity() throws {
        let x=try DerivativeFixtures.pendulum()
        var s=MechanicalDerivativeWorkspace(), w=try DerivativeFixtures.work(iterations:0), l=try DerivativeFixtures.loadWork(), calls=try DerivativeSupplierWork(maximumCalls:1000)
        do { _=try ExactMechanicalDifferentiator().forwardJacobian(x,variable:.drive,jointPolicy:DerivativeFixtures.jointPolicy(),admission:DerivativeFixtures.admission(),
            solvePolicy:DerivativeFixtures.solvePolicy(1),policy:DerivativeFixtures.policy(),workspace:&s,loadWork:&l,supplierWork:&calls,work:&w); Issue.record("Expected iteration budget failure") }
        catch let error as DerivativeError { guard case .numerical(.resourceLimit(resource:.iterations,limit:0))=error else { throw error } }
        let rejected=try DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:LinearTolerance(absoluteResidual:1e-9,relativeResidual:1e-9,pivotThreshold:10),coordinateScales:[1],energyScale:1,timeScale:1)
        w=try DerivativeFixtures.work()
        do { _=try ExactMechanicalDifferentiator().forwardDirection(x,direction:DerivativeFixtures.zero(x),jointPolicy:DerivativeFixtures.jointPolicy(),admission:DerivativeFixtures.admission(),
            solvePolicy:rejected,policy:DerivativeFixtures.policy(),workspace:&s,loadWork:&l,supplierWork:&calls,work:&w); Issue.record("Expected actual supplier pivot failure") }
        catch let error as DerivativeError { guard case .dynamics(.numerical(_,failedSupplierWorkUnavailable:true),failedSupplierWorkUnavailable:true)=error else { throw error } }
        #expect(calls.calls > 0); #expect(w.operations > 0)
    }
    @Test func separateLoadBudgetAndExplicitPrecisionFailure() throws {
        let x=try DerivativeFixtures.pendulum(), d=DerivativeFixtures.zero(x)
        var s=MechanicalDerivativeWorkspace(), w=try DerivativeFixtures.work(), l=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0)), calls=try DerivativeSupplierWork(maximumCalls:1000)
        do { _=try ExactMechanicalDifferentiator().direction(x,direction:d,jointPolicy:DerivativeFixtures.jointPolicy(),admission:DerivativeFixtures.admission(),
            policy:DerivativeFixtures.policy(),workspace:&s,loadWork:&l,supplierWork:&calls,work:&w); Issue.record("Expected separate load-work exhaustion") }
        catch let error as DerivativeError { guard case .dynamics(.loads(.workExhausted),failedSupplierWorkUnavailable:false)=error else { throw error } }
        let precision=try DynamicsSolvePolicy(capability:LinearCapability(precision:.float32,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:LinearTolerance(absoluteResidual:1e-9,relativeResidual:1e-9,pivotThreshold:1e-12),coordinateScales:[1],energyScale:1,timeScale:1)
        w=try DerivativeFixtures.work(); l=try DerivativeFixtures.loadWork()
        do { _=try ExactMechanicalDifferentiator().forwardDirection(x,direction:d,jointPolicy:DerivativeFixtures.jointPolicy(),admission:DerivativeFixtures.admission(),
            solvePolicy:precision,policy:DerivativeFixtures.policy(),workspace:&s,loadWork:&l,supplierWork:&calls,work:&w); Issue.record("Expected explicit precision rejection") }
        catch let error as DerivativeError { guard case .dynamics(.numerical(.unsupportedCapability,failedSupplierWorkUnavailable:false),failedSupplierWorkUnavailable:false)=error else { throw error } }
    }
    @Test func metadataByteTraversalIsBudgetedBeforePrimal() throws {
        let short=try DerivativeFixtures.freeBody(), p=try DerivativeFixtures.properties(2), key=String(repeating:"x",count:20000)
        let long=try DerivativeFixtures.input([DerivativeFixtures.body(key,p)],[],[DerivativeFixtures.inertia(key,p)],q:[0,0,0,1,0,0,0],v:[0,0,0,0,0,0],acceleration:[0,0,0,0,0,0],base:.spatialFloating)
        for (x,shouldFail) in [(short,false),(long,true)] {
            var s=TreeTangentWorkspace(), w=try DerivativeFixtures.work(operations:10000), calls=try DerivativeSupplierWork(maximumCalls:100)
            let d=DerivativeFixtures.zero(x).tree
            do { _=try ExactTreeDifferentiator().direction(x.tree,state:x.state,direction:d,jointPolicy:DerivativeFixtures.jointPolicy(),policy:DerivativeFixtures.policy(),
                workspace:&s,supplierWork:&calls,work:&w); #expect(!shouldFail) }
            catch let error as DerivativeError {
                guard shouldFail, case .numerical(.resourceLimit(resource:.arithmeticOperations,limit:10000))=error else { throw error }
                #expect(calls.calls == 0)
            }
        }
    }

}
