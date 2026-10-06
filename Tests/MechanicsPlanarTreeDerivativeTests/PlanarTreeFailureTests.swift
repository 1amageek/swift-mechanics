import SwiftMechanics
import Testing

@Suite struct PlanarTreeFailureTests {
    @Test func revisionShapeNonfiniteAndUnsupportedDirections() throws {
        let x=try PlanarTreeFixtures.hinge()
        let invalid=[TreeDirection(revision:10,configuration:[0],velocity:[0],acceleration:[0],screwPitch:[0]),
            TreeDirection(revision:9,configuration:[],velocity:[0],acceleration:[0],screwPitch:[0]),
            TreeDirection(revision:9,configuration:[.nan],velocity:[0],acceleration:[0],screwPitch:[0]),
            TreeDirection(revision:9,configuration:[0],velocity:[0],acceleration:[0],screwPitch:[1])]
        for (kind,d) in invalid.enumerated() {
            var scratch=TreeTangentWorkspace(), work=try PlanarTreeFixtures.work(), calls=try DerivativeSupplierWork(maximumCalls:100)
            do {
                _=try ExactPlanarTreeDifferentiator().direction(x.tree,state:x.state,direction:d,jointPolicy:PlanarTreeFixtures.jointPolicy(),policy:PlanarTreeFixtures.policy(),workspace:&scratch,supplierWork:&calls,work:&work)
                Issue.record("Invalid direction published a tangent.")
            } catch let error as DerivativeError {
                switch (kind,error) {
                case (0,.staleBinding),(1,.invalidShape),(2,.invalidInput),(3,.derivativeUnavailable): break
                default: throw error
                }
            }
            #expect(calls.calls == 0)
        }
    }
    @Test func spatialDomainAndOutOfPlanePrescribedDirectionsRefuseBeforeSupplier() throws {
        let spatial=try PlanarTreeFixtures.make([PlanarTreeFixtures.body("root",spatial:true)],[],q:[],v:[],a:[],dq:[],dv:[],da:[])
        let moving=try PlanarTreeFixtures.prescribed()
        for kind in 0..<2 {
            let x=kind == 0 ? spatial : moving
            let d=kind == 0 ? x.direction : TreeDirection(revision:9,configuration:[0],velocity:[0],acceleration:[0],screwPitch:[0],
                prescribed:[FrameMotionDirection(translation:.unitZ),FrameMotionDirection()])
            var scratch=TreeTangentWorkspace(), work=try PlanarTreeFixtures.work(), calls=try DerivativeSupplierWork(maximumCalls:100)
            do {
                _=try ExactPlanarTreeDifferentiator().direction(x.tree,state:x.state,direction:d,jointPolicy:PlanarTreeFixtures.jointPolicy(),policy:PlanarTreeFixtures.policy(),workspace:&scratch,supplierWork:&calls,work:&work)
                Issue.record("Unsupported domain published a tangent.")
            } catch let error as DerivativeError { guard case .derivativeUnavailable=error else { throw error } }
            #expect(calls.calls == 0 && x.state.revision == 9)
        }
    }
    @Test func actualSupplierMissingSampleStaleSampleNonplanarSampleAndCoordinateFailure() throws {
        let x=try PlanarTreeFixtures.prescribed(), first=x.state.prescribedAnchors[0]
        for kind in 0..<4 {
            var samples=x.state.prescribedAnchors
            if kind == 0 { samples=[] }
            if kind == 1 { samples[0]=try PrescribedAnchorState(frame:first.frame,time:1,motion:first.motion) }
            if kind == 2 {
                samples[0]=try PrescribedAnchorState(frame:first.frame,time:x.state.time,
                    motion:FrameMotion(pose:RigidTransform(rotation:.identity,translation:.unitZ),velocity:SpatialMotion(angular:.zero,linear:.zero),acceleration:SpatialMotion(angular:.zero,linear:.zero)))
            }
            let state=try KinematicState(revision:9,time:x.state.time,q:kind == 3 ? [] : x.state.q,v:x.state.v,acceleration:x.state.acceleration,prescribedAnchors:samples)
            let d=TreeDirection(revision:9,configuration:[0],velocity:[0],acceleration:[0],screwPitch:[0],prescribed:[FrameMotionDirection](repeating:FrameMotionDirection(),count:samples.count))
            var scratch=TreeTangentWorkspace(), work=try PlanarTreeFixtures.work(), calls=try DerivativeSupplierWork(maximumCalls:100)
            do {
                _=try ExactPlanarTreeDifferentiator().direction(x.tree,state:state,direction:d,jointPolicy:PlanarTreeFixtures.jointPolicy(),policy:PlanarTreeFixtures.policy(),workspace:&scratch,supplierWork:&calls,work:&work)
                Issue.record("Original supplier failure published a tangent.")
            } catch let error as DerivativeError {
                switch (kind,error) {
                case (0,.joints(.missingDerivativeData,failedSupplierWorkUnavailable:true)),
                     (1,.joints(.staleDerivativeData,failedSupplierWorkUnavailable:true)),
                     (2,.joints(.nonplanarGeometry,failedSupplierWorkUnavailable:true)),
                     (3,.joints(.invalidCoordinateCount,failedSupplierWorkUnavailable:true)): break
                default: throw error
                }
            }
            #expect(calls.calls == 1 && work.operations > 0)
            #expect(state.q == (kind == 3 ? [] : x.state.q))
        }
    }
    @Test func storageOperationSupplierAndCapacityBudgetsAndCancellation() throws {
        let x=try PlanarTreeFixtures.hinge()
        for kind in 0..<5 {
            var scratch=TreeTangentWorkspace(), work=try PlanarTreeFixtures.work(storage:kind == 0 ? 0 : 1000000,operations:kind == 1 ? 0 : 10000000)
            var calls=try DerivativeSupplierWork(maximumCalls:kind == 2 ? 0 : 100)
            do {
                _=try ExactPlanarTreeDifferentiator().direction(x.tree,state:x.state,direction:x.direction,jointPolicy:PlanarTreeFixtures.jointPolicy(),
                    policy:PlanarTreeFixtures.policy(cancelled:kind == 3,maximumBodies:kind == 4 ? 1 : 20),workspace:&scratch,supplierWork:&calls,work:&work)
                Issue.record("Budget or cancellation published a tangent.")
            } catch let error as DerivativeError {
                switch (kind,error) {
                case (0,.numerical(.resourceLimit(resource:.scalarStorage,limit:0))),
                     (1,.numerical(.resourceLimit(resource:.arithmeticOperations,limit:0))),
                     (2,.capacityExceeded),(3,.cancelled),(4,.capacityExceeded): break
                default: throw error
                }
            }
            #expect(calls.calls == 0)
        }
    }
    @Test func retainedInitializedScratchIsPrechargedBeforeMutation() throws {
        let x=try PlanarTreeFixtures.hinge()
        var scratch=TreeTangentWorkspace(), work=try PlanarTreeFixtures.work(storage:2336), calls=try DerivativeSupplierWork(maximumCalls:100)
        let out=try ExactPlanarTreeDifferentiator().direction(x.tree,state:x.state,direction:x.direction,jointPolicy:PlanarTreeFixtures.jointPolicy(),policy:PlanarTreeFixtures.policy(),workspace:&scratch,supplierWork:&calls,work:&work)
        #expect(work.peakScalarStorage == 2336)
        let saved=out.bodies[1].translation
        work=try PlanarTreeFixtures.work(storage:2336); calls=try DerivativeSupplierWork(maximumCalls:100)
        do {
            _=try ExactPlanarTreeDifferentiator().direction(x.tree,state:x.state,direction:x.direction,jointPolicy:PlanarTreeFixtures.jointPolicy(),policy:PlanarTreeFixtures.policy(),workspace:&scratch,supplierWork:&calls,work:&work)
            Issue.record("Retained initialized scratch escaped the storage limit.")
        } catch let error as DerivativeError {
            guard case .numerical(.resourceLimit(resource:.scalarStorage,limit:2336))=error else { throw error }
        }
        #expect(calls.calls == 0 && out.bodies[1].translation == saved)
    }
    @Test func supplierColumnLookupBudgetReportsSpentPrimalCall() throws {
        let x=try PlanarTreeFixtures.hinge()
        var scratch=TreeTangentWorkspace(), work=try PlanarTreeFixtures.work(), calls=try DerivativeSupplierWork(maximumCalls:1)
        do {
            _=try ExactPlanarTreeDifferentiator().direction(x.tree,state:x.state,direction:x.direction,jointPolicy:PlanarTreeFixtures.jointPolicy(),policy:PlanarTreeFixtures.policy(),workspace:&scratch,supplierWork:&calls,work:&work)
            Issue.record("Column supplier budget published a tangent.")
        } catch let error as DerivativeError { guard case .capacityExceeded=error else { throw error } }
        #expect(calls.calls == 1 && work.operations > 0)
    }
}
