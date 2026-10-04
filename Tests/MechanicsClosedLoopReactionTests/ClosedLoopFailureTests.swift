import SwiftMechanics
import Testing

@Suite struct ClosedLoopFailureTests {
    private func refused(_ input:ClosedLoopReactionInput,policy:ClosedLoopReactionPolicy,
                         matching:(ClosedLoopReactionError)->Bool) throws {
        var work=try LoopFixtures.work(),loads=try LoopFixtures.loads()
        do throws(ClosedLoopReactionError) {
            _=try ClosedLoopReactionRecovery().recover(input,outputFrame:input.geometry.model.tree.worldFrame,policy:policy,loadWork:&loads,work:&work)
            Issue.record("Invalid physical source was published.")
        } catch { #expect(matching(error)) }
    }
    @Test func originalGeneralizedDriveAndInputLoadsAreUnallocatable() throws {
        let input=try LoopFixtures.input(),policy=try LoopFixtures.policy()
        try refused(LoopFixtures.replacing(input,drive:[10,0]),policy:policy) { if case .unallocatableGeneralizedLoad=$0 { true } else { false } }
        let model=try LoopFixtures.model(),system=try LoopFixtures.system(model,state:input.state,generalized:true)
        let motion=try LoopFixtures.motion(system,rows:input.physicalRows)
        try refused(LoopFixtures.replacing(input,dynamics:system,motion:motion),policy:policy) { if case .unallocatableGeneralizedLoad=$0 { true } else { false } }
        // Omitting a real drive declaration still cannot bypass original physical balance.
        let driven=try LoopFixtures.motion(input.dynamics,rows:input.physicalRows,drive:[3,0])
        try refused(LoopFixtures.replacing(input,motion:driven),policy:policy) { if case .tree(.originalGeneralizedResidual)=$0 { true } else { false } }
    }
    @Test func sourceTimeGeometryRowsAndPhysicalInputCannotBeReused() throws {
        let input=try LoopFixtures.input(),model=input.geometry.model,policy=try LoopFixtures.policy()
        let later=try KinematicState(revision:1,time:0.5,q:input.state.q,v:input.state.v,acceleration:input.state.acceleration)
        try refused(LoopFixtures.replacing(input,state:later),policy:policy) { if case .staleSource=$0 { true } else { false } }
        let moved=try KinematicState(revision:1,time:0,q:[0.1,2.1],v:[0,0],acceleration:[0,0])
        let movedRows=try LoopFixtures.rows(input.geometry,state:moved),movedSystem=try LoopFixtures.system(model,state:moved)
        try refused(LoopFixtures.replacing(input,dynamics:movedSystem,state:moved,rows:movedRows),policy:policy) { if case .geometry=$0 { true } else { false } }
        let scaled=try LoopFixtures.input(scale:2)
        try refused(LoopFixtures.replacing(input,motion:scaled.motion),policy:policy) { if case .originalGeneralizedReaction=$0 { true } else { false } }
        let duplicate=try LoopFixtures.input(duplicate:true)
        try refused(LoopFixtures.replacing(input,motion:duplicate.motion),policy:policy) { if case .invalidShape=$0 { true } else { false } }
        let otherID=try LoopFixtures.geometry(model,rowID:93),otherRows=try LoopFixtures.rows(otherID,state:input.state)
        try refused(LoopFixtures.replacing(input,geometry:otherID,rows:otherRows),policy:policy) { if case .staleSource=$0 { true } else { false } }
        let stronger=try LoopFixtures.system(model,state:input.state,force:11)
        try refused(LoopFixtures.replacing(input,dynamics:stronger),policy:policy) { if case .tree(.originalGeneralizedResidual)=$0 { true } else { false } }
    }
    @Test func originalPositionAndVelocityMustBeFeasible() throws {
        let input=try LoopFixtures.input(),policy=try LoopFixtures.policy()
        let gap=try LoopFixtures.geometry(input.geometry.model,target:3),gapRows=try LoopFixtures.rows(gap,state:input.state)
        let gapMotion=try LoopFixtures.motion(input.dynamics,rows:gapRows)
        try refused(LoopFixtures.replacing(input,geometry:gap,rows:gapRows,motion:gapMotion),policy:policy) { if case .originalGeometry(row:91)=$0 { true } else { false } }
        let moving=try KinematicState(revision:1,time:0,q:[0,2],v:[1,0],acceleration:[0,0])
        let movingRows=try LoopFixtures.rows(input.geometry,state:moving),movingSystem=try LoopFixtures.system(input.geometry.model,state:moving)
        let movingMotion=try LoopFixtures.motion(movingSystem,rows:movingRows)
        try refused(LoopFixtures.replacing(input,dynamics:movingSystem,state:moving,rows:movingRows,motion:movingMotion),policy:policy) { if case .originalGeometry(row:91)=$0 { true } else { false } }
    }
    @Test func impulsePlanarSupportAndUnrepresentedConnectionsAreUnavailable() throws {
        let input=try LoopFixtures.input(),policy=try LoopFixtures.policy()
        let impulse=try LoopFixtures.motion(input.dynamics,rows:input.physicalRows,impulse:true)
        #expect(impulse.temporalMeaning == .instantaneousVelocityImpulse)
        try refused(LoopFixtures.replacing(input,motion:impulse),policy:policy) { if case .unsupportedTemporalMeaning=$0 { true } else { false } }
        let planar=try LoopFixtures.model(planar:true),geometry=try LoopFixtures.geometry(planar)
        let rows=try LoopFixtures.rows(geometry,state:planar.descriptor.initialState)
        try refused(LoopFixtures.replacing(input,geometry:geometry,rows:rows),policy:policy) { if case .unsupportedPlanar=$0 { true } else { false } }
        let support=try LoopFixtures.geometry(input.geometry.model,support:true)
        try refused(LoopFixtures.replacing(input,geometry:support),policy:policy) { if case .unsupportedSupportDomain=$0 { true } else { false } }
        try refused(LoopFixtures.replacing(input,topology:.unrepresentedConnections),policy:policy) { if case .unrepresentedConnections=$0 { true } else { false } }
    }
    @Test func capacityWorkCancellationAndChangedSupplierSourceRefusePublication() throws {
        let input=try LoopFixtures.input(),frame=input.geometry.model.tree.worldFrame,policy=try LoopFixtures.policy()
        try refused(input,policy:LoopFixtures.policy(bodyLoads:2)) { if case .capacityExceeded=$0 { true } else { false } }
        try refused(input,policy:LoopFixtures.policy(cancelled:true)) { if case .cancelled=$0 { true } else { false } }
        for storage in [true,false] {
            var work=try LoopFixtures.work(storage:storage ? 0 : 4_000_000,operations:storage ? 50_000_000 : 0),loads=try LoopFixtures.loads()
            do throws(ClosedLoopReactionError) {
                _=try ClosedLoopReactionRecovery().recover(input,outputFrame:frame,policy:policy,loadWork:&loads,work:&work)
                Issue.record("Exhausted numerical work published output.")
            } catch { if case .numerical=error {} else { Issue.record("Expected numerical limit.") } }
            #expect(loads.consumed == 0)
        }
        var work=try LoopFixtures.work(),loads=try LoopFixtures.loads()
        do throws(ClosedLoopReactionError) {
            _=try ClosedLoopReactionRecovery(equations:LoopEquationFault(mode:.changedInput)).recover(input,outputFrame:frame,policy:policy,loadWork:&loads,work:&work)
            Issue.record("Changed augmented original source published output.")
        } catch { if case .invalidSupplierEvidence=error {} else { Issue.record("Expected augmented source rejection.") } }
    }
}
