import SwiftMechanics
import Testing

@Suite struct TrajectoryManifoldTests {
    @Test func rootOnlyAndDynamicTangentAssemblyRetainActualNewLawAndOriginalRows() throws {
        for planar in [true,false] { for descendants in [false,true] {
            let fixture=try TrajectoryGeometryFixtures(planar:planar,descendants:descendants),initial=fixture.model.descriptor.initialState
            let policy=try GeometricFixtures.policy(initial.v.count)
            var q=initial.q
            if descendants { q[try GeometricFixtures.entry(fixture.model,"b").positions.start]+=0.03 }
            let state=try KinematicState(revision:1,time:0,q:q,v:initial.v,acceleration:initial.acceleration)
            var work=try GeometricFixtures.work()
            let result=try TangentManifoldAssembler(activeRanker:WeightedConstraintAssembler()).assemble(fixture.system,initial:state,policy:policy,work:&work)
            let p=fixture.program.layout.positionCount,k=fixture.program.layout.velocityCount
            #expect(Array(result.state.q[..<p]) == Array(initial.q[..<p]) && result.state.v == initial.v && result.state.acceleration == initial.acceleration)
            #expect(result.geometry.velocity.layout.scales.count == initial.v.count)
            #expect(result.activeRank?.activeCoordinates == Array(k..<initial.v.count))
            #expect(result.rank.rank == (descendants ? 1 : 0))
            if descendants {
                let a=try GeometricFixtures.entry(fixture.model,"a"),b=try GeometricFixtures.entry(fixture.model,"b")
                #expect(abs(result.state.q[a.positions.start]-result.state.q[b.positions.start]) < 1e-9 && result.geometry.velocity.rowIDs == [41,42])
            } else { #expect(result.state == initial && result.geometry.velocity.rowIDs.isEmpty) }
            var delta=[Double](repeating:0,count:initial.v.count);delta[0]=0.001
            do throws(GeometricConstraintError) { _=try ManifoldRetraction.retract(fixture.system,state:initial,dimensionlessTangent:delta,policy:policy.constraints.evaluation,work:&work);Issue.record("Known motion corrected") }
            catch { if case .invalidInput=error {} else { Issue.record("Wrong prescribed correction refusal") } }
        } }
    }
}
