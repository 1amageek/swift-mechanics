import Foundation
import SwiftMechanics
import Testing

@Suite struct PrescribedGeometryTests {
    @Test func realMovingNamedAnchorRowsHaveIndependentPhysicalDerivatives() throws {
        let fixture=try PrescribedGeometryFixture(),system=try fixture.system(alignment:false)
        let time=0.2,q=0.35,v=0.7,a=0.4,state=try fixture.state(time:time,q:[q],v:[v],acceleration:[a])
        var work=try GeometricFixtures.work()
        let sample=try GeometricRelationEvaluator().evaluate(system,state:state,policy:GeometricFixtures.evaluation(),work:&work)
        let theta=0.4+0.5*time+0.1*time*time,w=0.5+0.2*time
        let value=[cos(theta+q)-cos(theta),sin(theta+q)-sin(theta),0]
        let rate=[-sin(theta+q)*(w+v)+sin(theta)*w,cos(theta+q)*(w+v)-cos(theta)*w,0]
        let second=[-sin(theta+q)*(0.2+a)-cos(theta+q)*(w+v)*(w+v)+sin(theta)*0.2+cos(theta)*w*w,
                    cos(theta+q)*(0.2+a)-sin(theta+q)*(w+v)*(w+v)-cos(theta)*0.2+sin(theta)*w*w,0]
        for i in 0..<3 {
            let evaluatedRate=(sample.velocity.rows[i]*v*system.layout.timeScale/system.layout.scales[0]+sample.velocity.drift[i])/system.layout.timeScale
            let evaluatedSecond=(sample.velocity.rows[i]*a*system.layout.timeScale*system.layout.timeScale/system.layout.scales[0]+sample.velocity.accelerationBias[i])/(system.layout.timeScale*system.layout.timeScale)
            #expect(abs(sample.values[i]-value[i]) < 1e-12)
            #expect(abs(evaluatedRate-rate[i]) < 1e-12);#expect(abs(evaluatedSecond-second[i]) < 1e-12)
        }
        #expect(system.isExplicitTime)
        try GeometricOriginalAcceptance.validate(sample,system:system,state:state,tolerance:1e-10,policy:GeometricFixtures.evaluation(),work:&work)
    }
    @Test func mixedChartRetractionPreservesOriginalMotionAndRejectsStaleSamples() throws {
        let fixture=try PrescribedGeometryFixture(spherical:true),system=try fixture.system(alignment:true)
        let rotation=try UnitQuaternion(axis:.unitZ,angle:0.05),state=try fixture.state(time:0.2,q:[rotation.w,rotation.x,rotation.y,rotation.z],v:[0,0,0.7],acceleration:[0,0,0])
        var work=try GeometricFixtures.work()
        let result=try TangentManifoldAssembler().assemble(system,initial:state,policy:GeometricFixtures.policy(3),work:&work)
        #expect(result.state.q.count == 4);#expect(result.state.v.count == 3);#expect(result.rank.rank == 2)
        #expect(result.state.prescribedAnchors == state.prescribedAnchors);#expect(result.state.time == state.time)
        #expect(abs(result.state.q.reduce(0) { $0+$1*$1 }-1) < 1e-12)
        let stale=try KinematicState(revision:1,time:0.21,q:state.q,v:state.v,acceleration:state.acceleration,prescribedAnchors:state.prescribedAnchors)
        let policy=try GeometricFixtures.evaluation()
        do throws(GeometricConstraintError) { _=try GeometricRelationEvaluator().evaluate(system,state:stale,policy:policy,work:&work);Issue.record("Stale motion accepted") }
        catch { if case .motion(.staleSource)=error {} else { Issue.record("Unexpected stale sample failure") } }
    }
}
