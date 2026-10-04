import SwiftMechanics
import Testing

@Suite struct PlanarReactionRecoveryTests {
    private func recover(_ system:PhysicalRigidDynamicsSystem,_ acceleration:[Double],frame:EntityID?=nil) throws->PlanarTreeReactionReport {
        var work=try ReactionFixtures.work(),loads=try ReactionFixtures.loadWork()
        let recovery:any PlanarTreeReactionRecovering=PlanarTreeReactionRecovery()
        return try recovery.recover(system,acceleration:acceleration,topology:.completeTree,
            outputFrame:frame ?? system.input.snapshot.tree.worldFrame,policy:PlanarReactionFixtures.policy(acceleration.count),loadWork:&loads,work:&work)
    }
    private func wrench(_ value:PlanarReactionWrench,x:Double,y:Double,z:Double) {
        #expect(abs(value.forceX-x)<1e-8)
        #expect(abs(value.forceY-y)<1e-8)
        #expect(abs(value.momentZ-z)<1e-8)
    }
    private func opposite(_ a:PlanarReactionWrench,_ b:PlanarReactionWrench) {
        wrench(b,x:-a.forceX,y:-a.forceY,z:-a.momentZ)
    }

    @Test(.timeLimit(.minutes(1))) func pendulumOriginalInertiaDistinctGravityAndActionReaction() throws {
        let input=try PlanarReactionFixtures.pendulum(),system=try PlanarReactionFixtures.system(input)
        let result=try recover(system,[-10.0/3])
        let cut=try #require(result.joints.first),support=try #require(result.support)
        // At theta=0: COM acceleration=(-1,-10/3), mass=2, Iz=4.
        // Hinge force=m*a-m*g=(-2,40/3); Iz*alpha+r cross m*a= -20.
        wrench(cut.parentOnChild,x:-2,y:40.0/3,z:0)
        opposite(cut.parentOnChild,cut.childOnParent)
        // Only the root support additionally carries the independent root mass=1 weight.
        wrench(support.supportOnRoot,x:-2,y:70.0/3,z:0)
        opposite(support.supportOnRoot,support.rootOnSupport)
        #expect(cut.referencePointWorld == .zero)
        #expect(cut.referencePoint == .zero)
        #expect(cut.parentBody == input.snapshot.bodies[0].body)
        #expect(try cut.childBody == ReactionFixtures.id(.body,"plane-bob"))
        #expect(cut.timeSeconds == 0 && cut.revision == 7)
        #expect(cut.temporalMeaning == .instantaneousContinuousForce)
        #expect(result.fidelity == .reducedPlanarRigidTreeBalance)
        #expect(result.topologyAssumption == .completeTree)
        #expect(result.system === system)
        #expect(result.maximumScaledOriginalGeneralizedResidual<1e-8)
        #expect(result.loadWork.consumed == 6)
    }

    @Test(.timeLimit(.minutes(1))) func identifiedOffsetLoadRotationAndRootMoment() throws {
        let input=try PlanarReactionFixtures.offsetSliders(),system=try PlanarReactionFixtures.system(input)
        let world=try recover(system,[5,-5])
        let firstBody=try ReactionFixtures.id(.body,"plane-first"),secondBody=try ReactionFixtures.id(.body,"plane-second")
        let first=try #require(world.joints.first { $0.childBody == firstBody })
        let second=try #require(world.joints.first { $0.childBody == secondBody })
        let support=try #require(world.support)
        // F=(10,5) at world Y; first aX=10/2, second absolute aX=5-5=0.
        // The first cut carries both bodies; the second cut carries only mass=3.
        wrench(first.parentOnChild,x:0,y:45,z:70)
        wrench(second.parentOnChild,x:0,y:30,z:0)
        // Second slider's world X=2 shifts its 30Y reaction by +60Mz.
        wrench(support.supportOnRoot,x:0,y:55,z:70)
        #expect(first.referencePointWorld == .zero)
        #expect(try second.referencePointWorld == Vector3(2,0,0))
        opposite(first.parentOnChild,first.childOnParent)
        opposite(second.parentOnChild,second.childOnParent)
        let frame=try ReactionFixtures.id(.frame,"plane-first-frame")
        let rotated=try recover(system,[5,-5],frame:frame)
        let rotatedFirst=try #require(rotated.joints.first { $0.childBody == first.childBody })
        let rotatedSecond=try #require(rotated.joints.first { $0.childBody == second.childBody })
        wrench(rotatedFirst.parentOnChild,x:45,y:0,z:70)
        wrench(try #require(rotated.support).supportOnRoot,x:55,y:0,z:70)
        #expect(rotatedSecond.referencePointWorld == second.referencePointWorld)
        #expect(abs(rotatedSecond.referencePoint.x)<1e-8)
        #expect(abs(rotatedSecond.referencePoint.y+2)<1e-8)
        #expect(rotatedSecond.referencePoint.z == 0)
        opposite(rotatedFirst.parentOnChild,rotatedFirst.childOnParent)
        #expect(rotated.loadWork.consumed == 9)
    }

    @Test(.timeLimit(.minutes(1))) func rawOffPlaneReferenceAndTransverseCoupleCancelBeforeReduction() throws {
        let load=try BodyWrenchContribution(body:ReactionFixtures.id(.body,"plane-bob"),frame:ReactionFixtures.id(.frame,"world"),
            referencePoint:Vector3(0,0,1),wrench:SpatialWrench(torque:Vector3(0,-10,0),force:Vector3(10,0,0)),channel:.applied)
        let input=try PlanarReactionFixtures.pendulum(loads:[load]),system=try PlanarReactionFixtures.system(input)
        let result=try recover(system,[-10.0/3])
        // rZ cross Fx produces +10My, exactly cancelled by the original -10My couple.
        wrench(try #require(result.joints.first).parentOnChild,x:-12,y:40.0/3,z:0)
        wrench(try #require(result.support).supportOnRoot,x:-12,y:70.0/3,z:0)
        #expect(input.bodyWrenches[0].referencePoint.z == 1)
        let nonplanar=try BodyWrenchContribution(body:load.body,frame:load.frame,referencePoint:load.referencePoint,
            wrench:SpatialWrench(torque:.zero,force:Vector3(10,0,0)),channel:.applied)
        #expect(throws:DynamicsError.nonplanarInput) {
            try PlanarReactionFixtures.system(PlanarReactionFixtures.pendulum(loads:[nonplanar]))
        }
    }

    @Test(.timeLimit(.minutes(1))) func originalAccelerationAllocationAndTopologyRefusals() throws {
        let system=try PlanarReactionFixtures.system(PlanarReactionFixtures.pendulum())
        do { _=try recover(system,[0]);Issue.record("Wrong original acceleration was accepted") }
        catch let error as ReactionPathError {
            guard case .originalGeneralizedResidual(let index,let scaled)=error else { Issue.record("Unexpected residual refusal: \(error)");return }
            #expect(index == 0 && abs(scaled-20)<1e-8)
        }
        let driven=try PlanarReactionFixtures.system(PlanarReactionFixtures.slider(generalized:true))
        #expect(throws:ReactionPathError.nonuniqueGeneralizedAllocation) { try recover(driven,[0]) }
        var work=try ReactionFixtures.work(),loads=try ReactionFixtures.loadWork()
        #expect(throws:ReactionPathError.unrepresentedConnections) {
            try PlanarTreeReactionRecovery().recover(system,acceleration:[-10.0/3],topology:.unrepresentedConnections,
                outputFrame:system.input.snapshot.tree.worldFrame,policy:PlanarReactionFixtures.policy(1),loadWork:&loads,work:&work)
        }
        #expect(loads.consumed == 0)
    }

    @Test(.timeLimit(.minutes(1))) func capacitiesCancellationAndNumericalLimitsPublishNoResult() throws {
        let system=try PlanarReactionFixtures.system(PlanarReactionFixtures.pendulum()),frame=system.input.snapshot.tree.worldFrame
        var work=try ReactionFixtures.work(),loads=try ReactionFixtures.loadWork()
        #expect(throws:ReactionPathError.capacityExceeded) {
            try PlanarTreeReactionRecovery().recover(system,acceleration:[-10.0/3],topology:.completeTree,outputFrame:frame,
                policy:PlanarReactionFixtures.policy(1,bodies:1),loadWork:&loads,work:&work)
        }
        #expect(throws:ReactionPathError.cancelled) {
            try PlanarTreeReactionRecovery().recover(system,acceleration:[-10.0/3],topology:.completeTree,outputFrame:frame,
                policy:PlanarReactionFixtures.policy(1,cancelled:true),loadWork:&loads,work:&work)
        }
        #expect(work.operations == 0 && loads.consumed == 0)
        #expect(throws:ReactionPathError.invalidShape) {
            try PlanarTreeReactionRecovery().recover(system,acceleration:[],topology:.completeTree,outputFrame:frame,
                policy:PlanarReactionFixtures.policy(1),loadWork:&loads,work:&work)
        }
        #expect(throws:ReactionPathError.invalidInput) {
            try PlanarTreeReactionRecovery().recover(system,acceleration:[.nan],topology:.completeTree,outputFrame:frame,
                policy:PlanarReactionFixtures.policy(1),loadWork:&loads,work:&work)
        }
        work=try ReactionFixtures.work(storage:0)
        do {
            _=try PlanarTreeReactionRecovery().recover(system,acceleration:[-10.0/3],topology:.completeTree,outputFrame:frame,
                policy:PlanarReactionFixtures.policy(1),loadWork:&loads,work:&work)
            Issue.record("Storage capacity was ignored")
        } catch let error as ReactionPathError {
            guard case .numerical=error else { Issue.record("Unexpected storage refusal: \(error)");return }
        }
        #expect(loads.consumed == 0)
        work=try ReactionFixtures.work(operations:0)
        #expect(throws:ReactionPathError.numerical(.resourceLimit(resource:.arithmeticOperations,limit:0))) {
            try PlanarTreeReactionRecovery().recover(system,acceleration:[-10.0/3],topology:.completeTree,outputFrame:frame,
                policy:PlanarReactionFixtures.policy(1),loadWork:&loads,work:&work)
        }
        work=try ReactionFixtures.work()
        var exhausted=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0))
        #expect(throws:ReactionPathError.loads(.workExhausted)) {
            try PlanarTreeReactionRecovery().recover(system,acceleration:[-10.0/3],topology:.completeTree,outputFrame:frame,
                policy:PlanarReactionFixtures.policy(1),loadWork:&exhausted,work:&work)
        }
    }

    @Test(.timeLimit(.minutes(1))) func foreignOriginalMassWithInvisibleTransverseProjectionIsRejected() throws {
        let system=try PlanarReactionFixtures.system(PlanarReactionFixtures.slider(mass:2,prescribedY:1))
        let foreign=try PlanarReactionFixtures.system(PlanarReactionFixtures.slider(mass:4,prescribedY:1))
        let body=try ReactionFixtures.id(.body,"plane-first")
        var originalWork=try ReactionFixtures.work(),foreignWork=try ReactionFixtures.work()
        let equations:any PhysicalRigidEquationComputing=RigidEquationKernel()
        let original=try equations.inertialWrench(system,body:body,acceleration:[0],referencePointWorld:.zero,work:&originalWork)
        let swapped=try equations.inertialWrench(foreign,body:body,acceleration:[0],referencePointWorld:.zero,work:&foreignWork)
        #expect(original.body == swapped.body && original.frame == swapped.frame && original.referencePoint == swapped.referencePoint)
        #expect(original.wrench.force.x == 0 && swapped.wrench.force.x == 0)
        #expect(original.wrench.force.y == 2 && swapped.wrench.force.y == 4)
        wrench(try #require(recover(system,[0]).joints.first).parentOnChild,x:0,y:2,z:0)
        var work=try ReactionFixtures.work(),loads=try ReactionFixtures.loadWork()
        #expect(throws:ReactionPathError.invalidSupplierEvidence) {
            try PlanarTreeReactionRecovery(equations:PlanarReactionEquationSupplier(foreign:foreign)).recover(system,acceleration:[0],
                topology:.completeTree,outputFrame:system.input.snapshot.tree.worldFrame,policy:PlanarReactionFixtures.policy(1),loadWork:&loads,work:&work)
        }
        #expect(work.operations>0 && loads.consumed == 0)
    }

    @Test(.timeLimit(.minutes(1))) func sameFrameForeignGravityWithZeroXProjectionIsRejected() throws {
        let system=try PlanarReactionFixtures.system(PlanarReactionFixtures.slider(gravity:true))
        let accepted=try recover(system,[0])
        wrench(try #require(accepted.joints.first).parentOnChild,x:0,y:20,z:0)
        wrench(try #require(accepted.support).supportOnRoot,x:0,y:30,z:0)
        var work=try ReactionFixtures.work(),loads=try ReactionFixtures.loadWork()
        #expect(throws:ReactionPathError.invalidSupplierEvidence) {
            try PlanarTreeReactionRecovery(gravity:PlanarReactionForeignGravity()).recover(system,acceleration:[0],topology:.completeTree,
                outputFrame:system.input.snapshot.tree.worldFrame,policy:PlanarReactionFixtures.policy(1),loadWork:&loads,work:&work)
        }
        #expect(loads.consumed == 3)
        #expect(work.operations>0)
    }

    @Test(.timeLimit(.minutes(1)),arguments:[false,true]) func numericalResetAfterActualBodyQueryCannotErasePrefix(fails:Bool) throws {
        let system=try PlanarReactionFixtures.system(PlanarReactionFixtures.slider())
        var work=try ReactionFixtures.work(),loads=try ReactionFixtures.loadWork()
        try work.chargeOperations(3)
        let originalBudget=work.budget
        do {
            _=try PlanarTreeReactionRecovery(equations:PlanarReactionEquationSupplier(reset:true,fails:fails)).recover(system,acceleration:[0],topology:.completeTree,
                outputFrame:system.input.snapshot.tree.worldFrame,policy:PlanarReactionFixtures.policy(1),loadWork:&loads,work:&work)
            Issue.record("Supplier numerical reset was accepted")
        } catch let error as ReactionPathError {
            #expect(error == .supplierLedgerReplaced)
            #expect(error.failedSupplierWorkUnavailable)
        }
        #expect(work.budget == originalBudget && work.operations>3 && work.peakScalarStorage>0)
        #expect(loads.consumed == 0)
    }

    @Test(.timeLimit(.minutes(1)),arguments:[0,3],[false,true]) func gravityResetAfterActualPointRetainsAdmissionAndCallerCancellation(prefix:Int,fails:Bool) throws {
        let system=try PlanarReactionFixtures.system(PlanarReactionFixtures.pendulum())
        var work=try ReactionFixtures.work(),loads=try ReactionFixtures.loadWork()
        try loads.charge(prefix)
        do {
            _=try PlanarTreeReactionRecovery(gravity:ReactionErasingGravity(failAfterReset:fails,replaceCancellation:true)).recover(system,acceleration:[-10.0/3],topology:.completeTree,
                outputFrame:system.input.snapshot.tree.worldFrame,policy:PlanarReactionFixtures.policy(1),loadWork:&loads,work:&work)
            Issue.record("Supplier gravity reset was accepted")
        } catch let error as ReactionPathError {
            #expect(error == .supplierLedgerReplaced)
            #expect(error.failedSupplierWorkUnavailable)
        }
        #expect(loads.consumed == prefix+1)
        #expect(!loads.budget.isCancelled())
        try loads.charge(1)
        #expect(loads.consumed == prefix+2)
    }

    @Test(.timeLimit(.minutes(1))) func cancellationDuringGravityMergeRetainsKnownAdmissionAndUnavailableMarker() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,visionOS 2.0,*) {
            let system=try PlanarReactionFixtures.system(PlanarReactionFixtures.pendulum()),flag=PlanarReactionCancellationFlag()
            var work=try ReactionFixtures.work()
            var loads=LoadWork(budget:try LoadBudget(maximumWork:1000,maximumScalars:0,isCancelled:{ flag.cancelled }))
            do {
                _=try PlanarTreeReactionRecovery(gravity:PlanarReactionCancellingGravity(flag:flag)).recover(system,acceleration:[-10.0/3],topology:.completeTree,
                    outputFrame:system.input.snapshot.tree.worldFrame,policy:PlanarReactionFixtures.policy(1),loadWork:&loads,work:&work)
                Issue.record("Cancelled merge published a result")
            } catch let error as ReactionPathError {
                #expect(error == .loadLedgerMerge(.cancelled))
                #expect(error.failedSupplierWorkUnavailable)
            }
            #expect(loads.consumed == 1)
            #expect(loads.budget.isCancelled())
            #expect(throws:LoadError.cancelled) { try loads.charge(1) }
        }
    }

    @Test(.timeLimit(.minutes(1))) func planarFreeBodyHasNoInventedSupportAndSpatialPortIsRefused() throws {
        let system=try PlanarReactionFixtures.system(PlanarReactionFixtures.floating())
        let result=try recover(system,[0,-10,0])
        #expect(result.joints.isEmpty && result.support == nil)
        #expect(result.maximumScaledOriginalGeneralizedResidual<1e-8)
        #expect(result.loadWork.consumed == 3)
        var work=try ReactionFixtures.work(),loads=try ReactionFixtures.loadWork()
        let spatial=try RigidEquationKernel().assemble(ReactionFixtures.pendulum(),admission:ReactionFixtures.admission(),loadWork:&loads,work:&work)
        #expect(throws:ReactionPathError.dynamics(.dimensionMismatch)) { try recover(PhysicalRigidDynamicsSystem(spatial:spatial),[0]) }
    }
}
