import SwiftMechanics
import Testing

@Suite struct PrescribedRootGeometryTests {
    @Test func actualRootOnlyFullLayoutAllowsZeroOriginalGeometryAndEmptyDynamicRank() throws {
        for planar in [true,false] {
            let fixture=try PrescribedRootGeometryFixture(planar:planar),initial=fixture.model.descriptor.initialState,n=initial.v.count
            var work=try GeometricFixtures.work()
            let sample=try GeometricRelationEvaluator().evaluate(fixture.system,state:initial,policy:GeometricFixtures.evaluation(),work:&work)
            #expect(sample.values.isEmpty && sample.velocity.rows.isEmpty && sample.velocity.layout.scales.count == n)
            let policy=try GeometricFixtures.policy(n)
            let projected=try TangentManifoldAssembler(activeRanker:WeightedConstraintAssembler()).assemble(fixture.system,initial:initial,policy:policy,work:&work)
            #expect(projected.state == initial && projected.rank.rank == 0 && projected.pathCorrection == 0)
            #expect(projected.activeRank?.activeCoordinates.isEmpty == true && projected.activeRank?.sample.layout.scales.count == n)
            let root=try #require(fixture.system.prescribedRoot)
            #expect(root.knownCoordinates == Array(0..<n) && root.dynamicCoordinates.isEmpty)
            #expect(initial.prescribedAnchors.isEmpty)
            let delta=[Double](repeating:0,count:n)
            #expect(try ManifoldRetraction.retract(fixture.system,state:initial,dimensionlessTangent:delta,policy:policy.constraints.evaluation,work:&work) == initial)
        }
    }
    @Test func dynamicTangentProjectionCorrectsActualLoopWithoutAlteringKnownRootChart() throws {
        for planar in [true,false] {
            let fixture=try PrescribedRootGeometryFixture(planar:planar,descendants:true),initial=fixture.model.descriptor.initialState
            let first=try GeometricFixtures.entry(fixture.model,"a"),second=try GeometricFixtures.entry(fixture.model,"b")
            var q=initial.q;q[second.positions.start]+=0.03
            let perturbed=try KinematicState(revision:1,time:0,q:q,v:initial.v,acceleration:initial.acceleration)
            var work=try GeometricFixtures.work()
            let policy=try GeometricFixtures.policy(initial.v.count),assembler=TangentManifoldAssembler(activeRanker:WeightedConstraintAssembler())
            let result=try assembler.assemble(fixture.system,initial:perturbed,policy:policy,work:&work)
            #expect(abs(result.state.q[first.positions.start]-result.state.q[second.positions.start]) < 1e-9)
            let p=fixture.program.layout.positionCount,k=fixture.program.layout.velocityCount
            #expect(Array(result.state.q[..<p]) == Array(initial.q[..<p]) && Array(result.state.v[..<k]) == Array(initial.v[..<k]))
            #expect(result.state.acceleration == initial.acceleration && result.pathCorrection > 0)
            #expect(result.rank.rank == 1 && result.rank.reactionNullity == 1)
            #expect(result.geometry.velocity.layout.scales.count == initial.v.count && result.geometry.velocity.rowIDs == [41,42])
            let snapshot=try fixture.model.evaluate(fixture.model.makeState(result.state)),a=try snapshot.body(GeometricFixtures.id(.body,"a")).motion,b=try snapshot.body(GeometricFixtures.id(.body,"b")).motion
            #expect(try a.pose.rotation.rotating(.unitX).cross(b.pose.rotation.rotating(.unitX)).magnitude() < 1e-9)
        }
    }
    @Test func externalRootMutationCorrectionCapabilityAndIdentityCollisionAreRejected() throws {
        let fixture=try PrescribedRootGeometryFixture(planar:true,descendants:true),initial=fixture.model.descriptor.initialState
        let policy=try GeometricFixtures.policy(initial.v.count)
        var work=try GeometricFixtures.work(),delta=[Double](repeating:0,count:initial.v.count);delta[0]=0.001
        do throws(GeometricConstraintError) { _=try ManifoldRetraction.retract(fixture.system,state:initial,dimensionlessTangent:delta,policy:policy.constraints.evaluation,work:&work);Issue.record("Known coordinate correction accepted") }
        catch { if case .invalidInput=error {} else { Issue.record("Wrong root correction refusal") } }
        var q=initial.q;q[0]+=0.01
        let changed=try KinematicState(revision:1,time:0,q:q,v:initial.v,acceleration:initial.acceleration)
        do throws(GeometricConstraintError) { _=try GeometricRelationEvaluator().evaluate(fixture.system,state:changed,policy:policy.constraints.evaluation,work:&work);Issue.record("Stale root accepted") }
        catch { if case .staleSource=error {} else { Issue.record("Wrong source refusal") } }
        do throws(ManifoldProjectionFailure) { _=try TangentManifoldAssembler().assemble(fixture.system,initial:initial,policy:policy,work:&work);Issue.record("Missing active-rank capability admitted") }
        catch { if case .unsupportedDomain=error.cause {} else { Issue.record("Wrong rank capability refusal") } }
        // Explicit collision is tested through the actual source constructor, after model/program preparation.
        let capacity=try GeometricConstraintCapacity(maximumBodies:8,maximumPositions:16,maximumVelocities:8,maximumRows:12,maximumMetadataBytes:50000)
        do throws(GeometricConstraintError) {
            _=try GeometricConstraintSystem(model:fixture.model,layout:fixture.system.layout,relations:fixture.system.relations,
                minimumPosition:fixture.system.minimumPosition,maximumPosition:fixture.system.maximumPosition,minimumTime:0,maximumTime:2,capacity:capacity,work:&work,prescribedBase:fixture.program,rootRowIDs:[41,43,44])
            Issue.record("Root row identity collision admitted")
        } catch { if case .invalidInput=error {} else { Issue.record("Wrong row collision refusal") } }
    }
}
