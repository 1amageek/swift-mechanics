import SwiftMechanics
import Testing
import Foundation

@Suite struct GeometricEvaluationTests {
    @Test func actualFourbarOriginalTrigonometricDerivativesAndFixedFrame() throws {
        let model=try GeometricFixtures.fourbar(),system=try GeometricFixtures.system(model,rows:GeometricFixtures.loopRows(),scales:[2,3,4])
        let q=[0.61,0.63,-0.58],v=[0.5,0.8,-0.2],state=try GeometricFixtures.state(model.descriptor.initialState,q:q,v:v)
        var work=try GeometricFixtures.work()
        let evaluator:any HolonomicGeometryProviding=GeometricRelationEvaluator()
        let result=try evaluator.evaluate(system,state:state,policy:GeometricFixtures.evaluation(),work:&work)
        let angle=q[0]+q[2],rate=v[0]+v[2]
        let g=[cos(q[0])+2*cos(angle)-2-cos(q[1]),sin(q[0])+2*sin(angle)-sin(q[1]),0]
        let velocity=[-sin(q[0])*v[0]-2*sin(angle)*rate+sin(q[1])*v[1],cos(q[0])*v[0]+2*cos(angle)*rate-cos(q[1])*v[1],0]
        let acceleration=[-cos(q[0])*v[0]*v[0]-2*cos(angle)*rate*rate+cos(q[1])*v[1]*v[1],-sin(q[0])*v[0]*v[0]-2*sin(angle)*rate*rate+sin(q[1])*v[1]*v[1],0]
        for r in 0..<3 {
            #expect(abs(result.values[r]-g[r]/2) < 1e-12)
            var actual=result.velocity.drift[r]
            for j in 0..<3 { actual+=result.velocity.rows[r*3+j]*v[j]*3/system.layout.scales[j] }
            #expect(abs(actual/3-velocity[r]/2) < 1e-12)
            #expect(abs(result.velocity.accelerationBias[r]/9-acceleration[r]/2) < 1e-12)
        }
        try GeometricOriginalAcceptance.validate(result,system:system,state:state,tolerance:1e-12,policy:GeometricFixtures.evaluation(),work:&work)
        #expect(result.velocity.rowIDs == [11,12,13]);#expect(result.snapshot.coordinateRate == v)
    }
    @Test func explicitTargetFirstSecondAndDistanceBias() throws {
        let model=try GeometricFixtures.fourbar(),target=try GeometricAnalyticTarget(value:Vector3(0.1,-0.2,0),rate:Vector3(0.3,0.2,0),second:Vector3(-0.1,0.4,0))
        let system=try GeometricFixtures.system(model,rows:GeometricFixtures.loopRows(target:target))
        let state=try GeometricFixtures.state(model.descriptor.initialState,v:[0,0,0],time:0.4);var work=try GeometricFixtures.work()
        let e=try GeometricRelationEvaluator().evaluate(system,state:state,policy:GeometricFixtures.evaluation(),work:&work)
        #expect(system.isExplicitTime)
        #expect(abs(e.values[0]+(0.1+0.3*0.4-0.05*0.16)/2) < 1e-12)
        #expect(abs(e.velocity.drift[0]+3*(0.3-0.1*0.4)/2) < 1e-12)
        #expect(abs(e.velocity.accelerationBias[1]+9*0.4/2) < 1e-12)
        let first=try GeometricFrameEndpoint(body:GeometricFixtures.id(.body,"crank"),frame:GeometricFixtures.id(.frame,"crank"),point:.unitX)
        let second=try GeometricFrameEndpoint(body:GeometricFixtures.id(.body,"ground"),frame:GeometricFixtures.id(.frame,"ground"))
        let length=try GeometricAnalyticTarget(value:Vector3(1,0,0),rate:Vector3(0.2,0,0),second:Vector3(0.1,0,0))
        let row=try GeometricRelation(kind:.distance,rowIDs:[1],first:first,second:second,target:length,scale:2)
        let distance=try GeometricFixtures.system(model,rows:[row]),moving=try GeometricFixtures.state(model.descriptor.initialState,time:0.4)
        let d=try GeometricRelationEvaluator().evaluate(distance,state:moving,policy:GeometricFixtures.evaluation(),work:&work)
        let l=1+0.2*0.4+0.05*0.16,ld=0.24
        #expect(abs(d.values[0]-(1-l*l)/8) < 1e-12)
        #expect(abs(d.velocity.drift[0]+3*l*ld/4) < 1e-12)
        #expect(abs(d.velocity.accelerationBias[0]+9*(ld*ld+l*0.1)/4) < 1e-12)
        #expect(distance.metadata != system.metadata)
    }
    @Test func mixedFloatingSphericalSixDOFActualBiasAndRetraction() throws {
        let model=try GeometricFixtures.mixed()
        let a=try GeometricFrameEndpoint(body:GeometricFixtures.id(.body,"sphere"),frame:GeometricFixtures.id(.frame,"sphere"),point:.unitX,axis:.unitX)
        let b=try GeometricFrameEndpoint(body:GeometricFixtures.id(.body,"free"),frame:GeometricFixtures.id(.frame,"free"),point:.unitX,axis:.unitX)
        let rows=[try GeometricRelation(kind:.coincidence,rowIDs:[1,2,3],first:a,second:b,target:GeometricAnalyticTarget(),scale:1),
                  try GeometricRelation(kind:.alignedAxes,rowIDs:[4,5],first:a,second:b,target:GeometricAnalyticTarget(),scale:1)]
        let system=try GeometricFixtures.system(model,rows:rows),state=model.descriptor.initialState;var work=try GeometricFixtures.work()
        let e=try GeometricRelationEvaluator().evaluate(system,state:state,policy:GeometricFixtures.evaluation(),work:&work)
        #expect(state.q.count == 18);#expect(state.v.count == 15)
        #expect(abs(e.velocity.accelerationBias[0]/9-0.51) < 1e-12)
        #expect(e.snapshot.coordinateRate.count == 18)
        let sphere=try GeometricFixtures.entry(model,"s"),free=try GeometricFixtures.entry(model,"f")
        #expect(abs(e.snapshot.coordinateRate[sphere.positions.start+3]-0.2) < 1e-12)
        var delta=[Double](repeating:0,count:15);delta[sphere.velocities.start+2]=0.2;delta[free.velocities.start+5] = -0.1;delta[0]=0.05
        let retracted=try ManifoldRetraction.retract(system,state:state,dimensionlessTangent:delta,policy:GeometricFixtures.evaluation(),work:&work)
        for start in try GeometricFixtures.quaternionStarts(model) { #expect(abs(retracted.q[start..<start+4].reduce(0){$0+$1*$1}-1) < 1e-12) }
        #expect(abs(retracted.q[0]-0.05) < 1e-12)
        #expect(abs(retracted.q[sphere.positions.start]-cos(0.1)) < 1e-12);#expect(abs(retracted.q[sphere.positions.start+3]-sin(0.1)) < 1e-12)
        #expect(retracted.v == state.v)
        // Independent planar relative-axis formula includes both moving frame directions, not an extra Ndot term.
        var tilted=state.q;tilted[free.positions.start+3]=cos(0.1);tilted[free.positions.start+6]=sin(0.1)
        let tiltedState=try GeometricFixtures.state(state,q:tilted),ep=try GeometricFixtures.evaluation()
        let analytic=try GeometricRelationEvaluator().evaluate(system,state:tiltedState,policy:ep,work:&work)
        #expect(analytic.velocity.rowIDs == [1,2,3,4,5])
        #expect(abs(analytic.values[3]) < 1e-12);#expect(abs(analytic.values[4]-sin(0.2)) < 1e-12)
        var derivative=analytic.velocity.drift[4]
        for j in state.v.indices { derivative+=analytic.velocity.rows[4*state.v.count+j]*state.v[j]*3/system.layout.scales[j] }
        #expect(abs(derivative/3-0.3*cos(0.2)) < 1e-12)
        #expect(abs(analytic.velocity.accelerationBias[4]/9+0.09*sin(0.2)) < 1e-12)
        #expect(abs(analytic.alignmentResiduals[0].z-sin(0.2)) < 1e-12)
        try GeometricOriginalAcceptance.validate(analytic,system:system,state:tiltedState,tolerance:1e-12,policy:ep,work:&work)
        var reversed=state.q;reversed[free.positions.start+3]=0;reversed[free.positions.start+6]=1
        let oppositeState=try GeometricFixtures.state(state,q:reversed)
        do throws(GeometricConstraintError) { _=try GeometricRelationEvaluator().evaluate(system,state:oppositeState,policy:ep,work:&work);Issue.record("Wrong hemisphere accepted") }
        catch { if case .branchViolation(row:4)=error {} else { Issue.record("Wrong hemisphere failure") } }
        let opposite=try GeometricRelation(kind:.alignedAxes,rowIDs:[4,5],first:a,second:b,target:GeometricAnalyticTarget(),scale:1,axisSign:-1)
        let oppositeSystem=try GeometricFixtures.system(model,rows:[rows[0],opposite])
        let acceptedOpposite=try GeometricRelationEvaluator().evaluate(oppositeSystem,state:oppositeState,policy:ep,work:&work)
        #expect(abs(acceptedOpposite.values[3])+abs(acceptedOpposite.values[4]) < 1e-12)
        #expect(acceptedOpposite.alignmentResiduals[0] == .zero)
        #expect(oppositeSystem.metadata != system.metadata)
    }
    @Test func nonidentityToggleRetainsTinyOriginalRowAndReportsRowRelativeRankLimitation() throws {
        let model=try GeometricFixtures.fourbar(angle:0),system=try GeometricFixtures.system(model,rows:GeometricFixtures.loopRows())
        var work=try GeometricFixtures.work()
        let sample=try GeometricRelationEvaluator().evaluate(system,state:model.descriptor.initialState,policy:GeometricFixtures.evaluation(),work:&work)
        // Independent exact trigonometric x derivatives are zero. Fixed-frame transform roundoff is retained, never truncated.
        let xRow=Array(sample.velocity.rows[0..<3]),magnitude=xRow.reduce(0) { max($0,abs($1)) }
        #expect(magnitude <= 128*Double.ulpOfOne)
        let policy=try GeometricFixtures.policy(3)
        let rank=try WeightedConstraintAssembler().rank(sample.velocity,policy:policy.constraints,work:&work)
        #expect(rank.rank == (magnitude == 0 ? 1 : 2))
        print("Original nonidentity toggle x-row: \(xRow); row-relative rank: \(rank.rank)")
        #expect(abs(sample.velocity.rows[3]-1.5) < 1e-14)
        #expect(abs(sample.velocity.rows[4]+0.5) < 1e-14)
        #expect(abs(sample.velocity.rows[5]-1) < 1e-14)
    }
    @Test func originalAcceptedValuesRemainAuthorityInsideDiagnosticTolerance() throws {
        let model=try GeometricFixtures.fourbar(),system=try GeometricFixtures.system(model,rows:GeometricFixtures.loopRows())
        var work=try GeometricFixtures.work();let state=model.descriptor.initialState
        let real=try GeometricRelationEvaluator().evaluate(system,state:state,policy:GeometricFixtures.evaluation(),work:&work)
        var values=real.values;values[0]+=0.5e-9
        let supplied=HolonomicGeometrySample(source:state,snapshot:real.snapshot,metadata:real.metadata,values:values,velocity:real.velocity)
        let accepted=try GeometricOriginalAcceptance.validatedSample(supplied,system:system,state:state,tolerance:1e-9,policy:GeometricFixtures.evaluation(),work:&work)
        #expect(abs(accepted.values[0]-real.values[0]) < 1e-14)
        #expect(abs(accepted.values[0]-supplied.values[0]) > 0.4e-9)
    }
    @Test func originalAcceptanceRejectsSameIdentityDifferentSourceAndChangedDiagnostic() throws {
        let model=try GeometricFixtures.fourbar(),system=try GeometricFixtures.system(model,rows:GeometricFixtures.loopRows())
        var work=try GeometricFixtures.work();let state=model.descriptor.initialState
        let other=try GeometricFixtures.state(state,q:[0.7,0.7,-0.7])
        let e=try GeometricRelationEvaluator().evaluate(system,state:other,policy:GeometricFixtures.evaluation(),work:&work)
        let forged=HolonomicGeometrySample(source:state,snapshot:e.snapshot,metadata:e.metadata,values:e.values,velocity:e.velocity)
        #expect(throws:GeometricConstraintError.self) { try GeometricOriginalAcceptance.validate(forged,system:system,state:state,tolerance:1e-9,policy:GeometricFixtures.evaluation(),work:&work) }
        let real=try GeometricRelationEvaluator().evaluate(system,state:state,policy:GeometricFixtures.evaluation(),work:&work)
        var rows=real.velocity.rows;rows[0]+=0.1
        let altered=HolonomicGeometrySample(source:state,snapshot:real.snapshot,metadata:real.metadata,values:real.values,
            velocity:VelocityConstraintSample(layout:system.layout,rowIDs:system.rowIDs,rows:rows,drift:real.velocity.drift,accelerationBias:real.velocity.accelerationBias,isIntegrable:true))
        #expect(throws:GeometricConstraintError.self) { try GeometricOriginalAcceptance.validate(altered,system:system,state:state,tolerance:1e-9,policy:GeometricFixtures.evaluation(),work:&work) }
    }
}
