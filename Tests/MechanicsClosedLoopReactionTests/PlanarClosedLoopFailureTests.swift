import SwiftMechanics
import Testing

@Suite struct PlanarClosedLoopFailureTests {
    private func refuse(_ input:PlanarClosedLoopReactionInput,_ expected:(ClosedLoopReactionError)->Bool) throws {
        var work=try LoopFixtures.work(),loads=try LoopFixtures.loads()
        let policy=try PlanarLoopFixtures.policy(input.dynamics.velocityCount)
        do throws(ClosedLoopReactionError) {
            _=try PlanarClosedLoopReactionRecovery().recover(input,outputFrame:input.geometry.model.tree.worldFrame,policy:policy,loadWork:&loads,work:&work)
            Issue.record("Invalid planar loop source published a report")
        } catch { #expect(expected(error)) }
    }
    @Test(.timeLimit(.minutes(1))) func originalTimeVelocityShapeGeometryAndAllocationSourceMustAgree() throws {
        let input=try PlanarLoopFixtures.input()
        let later=try KinematicState(revision:1,time:0.25,q:input.state.q,v:input.state.v,acceleration:input.state.acceleration)
        try refuse(PlanarLoopFixtures.replacing(input,state:later)) { if case .staleSource=$0 { return true };return false }
        let moving=try KinematicState(revision:1,time:0,q:input.state.q,v:[1,0,0],acceleration:input.state.acceleration)
        try refuse(PlanarLoopFixtures.replacing(input,state:moving)) { if case .staleSource=$0 { return true };return false }
        try refuse(PlanarLoopFixtures.replacing(input,drive:[0])) { if case .invalidShape=$0 { return true };return false }
        let other=try PlanarLoopFixtures.input(scale:1)
        try refuse(PlanarLoopFixtures.replacing(input,allocation:other.allocation)) { if case .geometry(.staleSource)=$0 { return true };return false }
        try refuse(PlanarLoopFixtures.replacing(input,topology:.unrepresentedConnections)) { if case .unrepresentedConnections=$0 { return true };return false }
        var q=input.state.q;q[0] += 0.1
        let state=try KinematicState(revision:1,time:0,q:q,v:input.state.v,acceleration:input.state.acceleration)
        let rows=try LoopFixtures.rows(input.geometry,state:state),system=try PlanarLoopFixtures.system(input.geometry.model,state:state)
        let motion=try PlanarLoopFixtures.motion(system,rows),allocation=try PlanarLoopFixtures.allocation(input.geometry,rows,state:state)
        let offManifold=PlanarLoopFixtures.replacing(input,motion:motion,state:state,allocation:allocation)
        try refuse(offManifold) { if case .originalGeometry=$0 { return true };return false }
    }
    @Test(.timeLimit(.minutes(1))) func impulseNonzeroOriginalDriveAndGeneralizedOnlyBodyAllocationRefuse() throws {
        let input=try PlanarLoopFixtures.input(),rows=input.allocation.rows
        let impulse=try PlanarLoopFixtures.motion(input.dynamics,rows,impulse:true)
        try refuse(PlanarLoopFixtures.replacing(input,motion:impulse)) { if case .unsupportedTemporalMeaning=$0 { return true };return false }
        try refuse(PlanarLoopFixtures.replacing(input,drive:[1,0,0])) { if case .unallocatableGeneralizedLoad=$0 { return true };return false }
        let sliders=try PlanarLoopFixtures.input(fourbar:false),system=try PlanarLoopFixtures.system(sliders.geometry.model,generalized:true)
        let motion=try PlanarLoopFixtures.motion(system,sliders.allocation.rows)
        try refuse(PlanarLoopFixtures.replacing(sliders,motion:motion)) { if case .unallocatableGeneralizedLoad=$0 { return true };return false }
    }
    @Test(.timeLimit(.minutes(1))) func falseZeroDriveCannotPassOriginalBodyGeneralizedBalance() throws {
        let input=try PlanarLoopFixtures.input()
        let driven=try PlanarLoopFixtures.motion(input.dynamics,input.allocation.rows,drive:[1,0,0])
        try refuse(PlanarLoopFixtures.replacing(input,motion:driven)) {
            if case .tree(.originalGeneralizedResidual)=$0 { return true };return false
        }
    }
    @Test(.timeLimit(.minutes(1))) func spatialPhysicalSourceAndChangedOriginalRowIdentityRefuse() throws {
        let input=try PlanarLoopFixtures.input(),spatial=try LoopFixtures.input()
        let physical=PhysicalRigidDynamicsSystem(spatial:spatial.dynamics)
        let motion=try PlanarLoopFixtures.motion(physical,spatial.physicalRows)
        let otherDimension=PlanarLoopFixtures.replacing(input,motion:motion,geometry:spatial.geometry,state:spatial.state)
        try refuse(otherDimension) { if case .dynamics(.dimensionMismatch)=$0 { return true };return false }
        let sliders=try PlanarLoopFixtures.input(fourbar:false),changed=try LoopFixtures.geometry(sliders.geometry.model,rowID:99)
        try refuse(PlanarLoopFixtures.replacing(sliders,geometry:changed)) { if case .staleSource=$0 { return true };return false }
    }
    @Test(.timeLimit(.minutes(1))) func actualAugmentedInputLoadAndInertiaSwapRefuse() throws {
        let input=try PlanarLoopFixtures.input(),foreign=try PlanarLoopFixtures.system(PlanarLoopFixtures.fourbarModel(mass:2))
        let policy=try PlanarLoopFixtures.policy(3)
        for mode in [PlanarLoopEquationFault.Mode.changedInput,.changedInertia] {
            var work=try LoopFixtures.work(),loads=try LoopFixtures.loads()
            do throws(ClosedLoopReactionError) {
                _=try PlanarClosedLoopReactionRecovery(equations:PlanarLoopEquationFault(mode:mode,foreign:foreign)).recover(input,
                    outputFrame:input.geometry.model.tree.worldFrame,policy:policy,loadWork:&loads,work:&work)
                Issue.record("Foreign original inventory was accepted")
            } catch { if case .invalidSupplierEvidence=error {} else { Issue.record("Unexpected inventory refusal") } }
            #expect(work.operations>0 && loads.consumed == 1)
        }
    }
    @Test(.timeLimit(.minutes(1))) func capacitiesCancellationAndWorkBoundsRefuseBeforePublication() throws {
        let input=try PlanarLoopFixtures.input(),frame=input.geometry.model.tree.worldFrame
        let cancelled=try PlanarLoopFixtures.policy(3,cancelled:true),bounded=try PlanarLoopFixtures.policy(3,rows:2),policy=try PlanarLoopFixtures.policy(3)
        var work=try LoopFixtures.work(),loads=try LoopFixtures.loads()
        do throws(ClosedLoopReactionError) {
            _=try PlanarClosedLoopReactionRecovery().recover(input,outputFrame:frame,policy:cancelled,loadWork:&loads,work:&work)
            Issue.record("Cancellation was ignored")
        }
        catch { if case .cancelled=error {} else { Issue.record("Unexpected cancellation failure") } }
        #expect(work.operations == 0 && loads.consumed == 0)
        do throws(ClosedLoopReactionError) {
            _=try PlanarClosedLoopReactionRecovery().recover(input,outputFrame:frame,policy:bounded,loadWork:&loads,work:&work)
            Issue.record("Row capacity was ignored")
        }
        catch { if case .capacityExceeded=error {} else { Issue.record("Unexpected row capacity failure") } }
        for storage in [true,false] {
            var limited=try LoopFixtures.work(storage:storage ? 0 : 4_000_000,operations:storage ? 50_000_000 : 0)
            do throws(ClosedLoopReactionError) {
                _=try PlanarClosedLoopReactionRecovery().recover(input,outputFrame:frame,policy:policy,loadWork:&loads,work:&limited)
                Issue.record("Numerical limit was ignored")
            } catch { if case .numerical=error {} else { Issue.record("Unexpected numerical bound failure") } }
        }
        #expect(loads.consumed == 0)
        var exhausted=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0))
        do throws(ClosedLoopReactionError) {
            _=try PlanarClosedLoopReactionRecovery().recover(input,outputFrame:frame,policy:policy,loadWork:&exhausted,work:&work)
            Issue.record("Load budget was ignored")
        } catch { if case .loads(.workExhausted)=error {} else { Issue.record("Unexpected load limit failure") } }
    }
}
