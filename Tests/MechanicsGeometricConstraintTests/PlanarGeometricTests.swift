import Testing
import Foundation
import SwiftMechanics

@Suite struct PlanarGeometricTests {
    @Test func planarOriginalFourbarRowsRatesBiasAndZeroRow() throws {
        let model = try GeometricFixtures.fourbar(planar:true)
        let system = try GeometricFixtures.system(model,rows:GeometricFixtures.loopRows(duplicate:true),scales:[2,3,4])
        let q = [0.61,0.63,-0.58], v = [0.5,0.8,-0.2]
        let state = try GeometricFixtures.state(model.descriptor.initialState,q:q,v:v)
        var work = try GeometricFixtures.work()
        let sample = try GeometricRelationEvaluator().evaluate(system,state:state,policy:GeometricFixtures.evaluation(),work:&work)
        let angle=q[0]+q[2],rate=v[0]+v[2]
        let g=[cos(q[0])+2*cos(angle)-2-cos(q[1]),sin(q[0])+2*sin(angle)-sin(q[1]),0]
        let speed=[-sin(q[0])*v[0]-2*sin(angle)*rate+sin(q[1])*v[1],cos(q[0])*v[0]+2*cos(angle)*rate-cos(q[1])*v[1],0]
        let bias=[-cos(q[0])*v[0]*v[0]-2*cos(angle)*rate*rate+cos(q[1])*v[1]*v[1],-sin(q[0])*v[0]*v[0]-2*sin(angle)*rate*rate+sin(q[1])*v[1]*v[1],0]
        for row in 0..<6 {
            #expect(abs(sample.values[row]-g[row%3]/2)<1e-12)
            var derivative=sample.velocity.drift[row]
            for j in 0..<3 { derivative+=sample.velocity.rows[row*3+j]*v[j]*3/system.layout.scales[j] }
            #expect(abs(derivative/3-speed[row%3]/2)<1e-12)
            #expect(abs(sample.velocity.accelerationBias[row]/9-bias[row%3]/2)<1e-12)
        }
        #expect(sample.velocity.rowIDs == [11,12,13,21,22,23])
        #expect(sample.velocity.rows[6..<9].allSatisfy({$0 == 0}))
        #expect(system.metadata.hasPrefix("body-frame-planar-holonomic-v4"))
        try GeometricOriginalAcceptance.validate(sample,system:system,state:state,tolerance:1e-12,policy:GeometricFixtures.evaluation(),work:&work)
    }
    @Test(.timeLimit(.minutes(1))) func planarAssemblyRetainsRedundancyAndToggle() throws {
        let model=try GeometricFixtures.fourbar(planar:true),system=try GeometricFixtures.system(model,rows:GeometricFixtures.loopRows(duplicate:true))
        let state=try GeometricFixtures.state(model.descriptor.initialState,q:[0.65,0.57,-0.52]);var work=try GeometricFixtures.work()
        let result=try TangentManifoldAssembler().assemble(system,initial:state,policy:GeometricFixtures.policy(3),work:&work)
        let q=result.state.q
        #expect(abs(cos(q[0])+2*cos(q[0]+q[2])-2-cos(q[1]))<2e-9)
        #expect(abs(sin(q[0])+2*sin(q[0]+q[2])-sin(q[1]))<2e-9)
        #expect(result.rank.rank == 2 && result.rank.reactionNullity == 4)
        #expect(result.geometry.velocity.rowIDs == [11,12,13,21,22,23])
        let toggleModel=try GeometricFixtures.fourbar(angle:0,nonidentityFrame:false,planar:true)
        let toggle=try GeometricFixtures.system(toggleModel,rows:GeometricFixtures.loopRows());work=try GeometricFixtures.work()
        let sample=try GeometricRelationEvaluator().evaluate(toggle,state:toggleModel.descriptor.initialState,policy:GeometricFixtures.evaluation(),work:&work)
        let rank=try WeightedConstraintAssembler().rank(sample.velocity,policy:GeometricFixtures.policy(3).constraints,work:&work)
        #expect(rank.rank == 1 && rank.reactionNullity == 2)
        #expect(sample.velocity.rows[0..<3].allSatisfy({$0 == 0}))
        #expect(sample.velocity.rows[6..<9].allSatisfy({$0 == 0}))
    }
    @Test func planarDistanceAndPlaneDomainRefusal() throws {
        let model=try GeometricPhysicalFixtures.sliders(),relation=try GeometricPhysicalFixtures.distance()
        let system=try GeometricFixtures.system(model,rows:[relation],scales:[2,3]);var work=try GeometricFixtures.work()
        let sample=try GeometricRelationEvaluator().evaluate(system,state:model.descriptor.initialState,policy:GeometricFixtures.evaluation(),work:&work)
        #expect(sample.values == [0] && sample.velocity.rows == [-1,1.5])
        let aligned=try GeometricRelation(kind:.alignedAxes,rowIDs:[1,2],first:relation.first,second:relation.second,target:GeometricAnalyticTarget(),scale:1)
        #expect(throws:GeometricConstraintError.self) { try GeometricFixtures.system(model,rows:[aligned]) }
        let out=try GeometricFrameEndpoint(body:relation.first.body,frame:relation.first.frame,point:Vector3(0,0,1))
        let outside=try GeometricRelation(kind:.distance,rowIDs:[1],first:out,second:relation.second,target:relation.target,scale:1)
        #expect(throws:GeometricConstraintError.self) { try GeometricFixtures.system(model,rows:[outside]) }
        let target=try GeometricRelation(kind:.coincidence,rowIDs:[1,2,3],first:relation.first,second:relation.second,target:GeometricAnalyticTarget(value:Vector3(0,0,1)),scale:1)
        #expect(throws:GeometricConstraintError.self) { try GeometricFixtures.system(model,rows:[target]) }
        let floating=try GeometricPhysicalFixtures.sliders(floating:true)
        #expect(throws:GeometricConstraintError.self) { try GeometricFixtures.system(floating,rows:[relation]) }
        let spatial=try GeometricPhysicalFixtures.sliders(planar:false)
        let spatialSystem=try GeometricFixtures.system(spatial,rows:[relation])
        #expect(system.metadata != spatialSystem.metadata)
        #expect(spatialSystem.metadata.hasPrefix("body-frame-holonomic-v2"))
    }
}
