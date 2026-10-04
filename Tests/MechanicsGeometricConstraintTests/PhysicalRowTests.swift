import Testing
import Foundation
import SwiftMechanics

@Suite struct PhysicalRowTests {
    private func close(_ a: Vector3, _ b: Vector3) throws -> Bool { try a.subtracting(b).magnitude() < 1e-10 }
    private func witness(_ system: GeometricConstraintSystem, state: KinematicState? = nil) throws -> GeometricPhysicalRowWitness {
        let source=state ?? system.model.descriptor.initialState
        var work=try GeometricFixtures.work()
        let provider:any HolonomicGeometryProviding=GeometricRelationEvaluator()
        let sample=try provider.evaluate(system,state:source,policy:GeometricFixtures.evaluation(),work:&work)
        return try provider.physicalRows(system,state:source,supplied:sample,policy:GeometricPhysicalFixtures.policy(),work:&work)
    }
    @Test func planarCovectorsRetainOriginalZeroRowsAndProjectOriginalColumns() throws {
        let model=try GeometricFixtures.fourbar(planar:true),system=try GeometricFixtures.system(model,rows:GeometricFixtures.loopRows(duplicate:true),scales:[2,3,4])
        let result=try witness(system)
        #expect(result.dimension == .planar && result.convention == .continuousForceEnergyCovector)
        #expect(result.fidelity == .reducedPlanarBodyPointCovectors)
        #expect(result.rows.map({$0.rowID}) == [11,12,13,21,22,23])
        #expect(result.original.velocity.rowIDs == result.rows.map({$0.rowID}))
        for (i,row) in result.rows.enumerated() {
            #expect(row.isStructuralZero == (i%3 == 2))
            let expected:Vector3 = i%3 == 0 ? .unitX : (i%3 == 1 ? .unitY : .zero)
            #expect(try close(row.first.linearGradient,expected.scaled(by:0.5)))
            #expect(try close(row.second.linearGradient,expected.scaled(by:-0.5)))
            #expect(row.first.angularGradient == .zero && row.second.angularGradient == .zero)
            for j in 0..<system.layout.scales.count {
                var actual=0.0
                for endpoint in [row.first,row.second] {
                    let body=try result.original.snapshot.body(endpoint.body)
                    let columns=try result.original.snapshot.geometricColumns(body:endpoint.body)
                    let c=columns[columns.startIndex+j]
                    let offset=try endpoint.referencePointWorld.subtracting(body.motion.pose.translation)
                    actual += try endpoint.linearGradient.dot(c.linear.adding(c.angular.cross(offset))) + endpoint.angularGradient.dot(c.angular)
                }
                #expect(abs(actual-result.original.velocity.rows[i*3+j]/system.layout.scales[j])<1e-10)
            }
        }
        var work=try GeometricFixtures.work()
        let rank=try WeightedConstraintAssembler().rank(result.original.velocity,policy:GeometricFixtures.policy(3).constraints,work:&work)
        #expect(rank.reactionNullity == 4 && !rank.reactionsUnique)
        let accepted=try GeometricPhysicalRowAcceptance.validated(result,system:system,state:model.descriptor.initialState,policy:GeometricPhysicalFixtures.policy(),work:&work)
        #expect(accepted.rows == result.rows)
    }
    @Test func distanceForceNormalizationAndActionReactionAtRealPoints() throws {
        let model=try GeometricPhysicalFixtures.sliders()
        let one=try GeometricFixtures.system(model,rows:[GeometricPhysicalFixtures.distance(scale:1)])
        let two=try GeometricFixtures.system(model,rows:[GeometricPhysicalFixtures.distance(scale:2)])
        let first=try #require(try witness(one).rows.first),second=try #require(try witness(two).rows.first)
        // The original geometric separation is -2 X. A physical -6/+6 pair uses multipliers 3 and 12 J.
        let a=try first.first.linearGradient.scaled(by:3),b=try second.first.linearGradient.scaled(by:12)
        #expect(try close(a,Vector3(-6,0,0)))
        #expect(try close(b,a))
        #expect(try close(a.adding(first.second.linearGradient.scaled(by:3)),.zero))
        #expect(first.first.referencePointWorld == .zero)
        #expect(try close(first.second.referencePointWorld,Vector3(2,0,0)))
        let moment=try first.first.referencePointWorld.cross(a).adding(first.second.referencePointWorld.cross(first.second.linearGradient.scaled(by:3)))
        #expect(try close(moment,.zero))
    }
    @Test func spatialCoincidenceAndMovingBasisAlignmentRemainPhysical() throws {
        let model=try GeometricFixtures.mixed()
        let a=try GeometricFrameEndpoint(body:GeometricFixtures.id(.body,"sphere"),frame:GeometricFixtures.id(.frame,"sphere"),point:.unitX,axis:.unitX)
        let b=try GeometricFrameEndpoint(body:GeometricFixtures.id(.body,"free"),frame:GeometricFixtures.id(.frame,"free"),point:.unitX,axis:.unitX)
        let rows=try [GeometricRelation(kind:.coincidence,rowIDs:[1,2,3],first:a,second:b,target:GeometricAnalyticTarget(),scale:1),
            GeometricRelation(kind:.alignedAxes,rowIDs:[4,5],first:a,second:b,target:GeometricAnalyticTarget(),scale:1)]
        let system=try GeometricFixtures.system(model,rows:rows),result=try witness(system)
        #expect(result.dimension == .spatial && result.rows.count == 5)
        #expect(result.fidelity == .spatialBodyPointCovectors)
        #expect(result.rows[2].first.linearGradient == .unitZ && !result.rows[2].isStructuralZero)
        #expect(try close(result.rows[3].first.angularGradient,Vector3(0,-1,0)))
        #expect(try close(result.rows[4].first.angularGradient,Vector3(0,0,-1)))
        for row in result.rows {
            #expect(try close(row.first.linearGradient.adding(row.second.linearGradient),.zero))
            #expect(try close(row.first.angularGradient.adding(row.second.angularGradient),.zero))
        }
        #expect(result.maximumProjectionResidual < 1e-10)
        #expect(result.metadata.hasPrefix("body-frame-holonomic-v2"))
        let free=try GeometricFixtures.entry(model,"f"),angle=0.2
        var q=model.descriptor.initialState.q
        q[free.positions.start+3]=cos(angle/2);q[free.positions.start+6]=sin(angle/2)
        let rotated=try witness(system,state:GeometricFixtures.state(model.descriptor.initialState,q:q))
        // The second frame's -Y transverse direction rotates to (sin(angle),-cos(angle),0).
        #expect(try close(rotated.rows[3].first.angularGradient,Vector3(0,-1,0)))
        #expect(try close(rotated.rows[4].first.angularGradient,Vector3(0,0,-cos(angle))))
    }
    @Test func sourceTimeIdentityRowsBoundsCancellationAndLimitsFailBeforeWitness() throws {
        let model=try GeometricPhysicalFixtures.sliders(),system=try GeometricFixtures.system(model,rows:[GeometricPhysicalFixtures.distance()])
        let state=model.descriptor.initialState,provider:any HolonomicGeometryProviding=GeometricRelationEvaluator()
        var work=try GeometricFixtures.work()
        let sample=try provider.evaluate(system,state:state,policy:GeometricFixtures.evaluation(),work:&work)
        let changedTime=try GeometricFixtures.state(state,time:0.1)
        #expect(throws:GeometricConstraintError.self) { try provider.physicalRows(system,state:changedTime,supplied:sample,policy:GeometricPhysicalFixtures.policy(),work:&work) }
        let changedSource=try GeometricFixtures.state(state,q:[0.1,2])
        let forged=HolonomicGeometrySample(source:changedSource,snapshot:sample.snapshot,metadata:sample.metadata,values:sample.values,velocity:sample.velocity)
        #expect(throws:GeometricConstraintError.self) { try provider.physicalRows(system,state:changedSource,supplied:forged,policy:GeometricPhysicalFixtures.policy(),work:&work) }
        let forgedIdentity=HolonomicGeometrySample(source:state,snapshot:sample.snapshot,metadata:"unrelated",values:sample.values,velocity:sample.velocity)
        #expect(throws:GeometricConstraintError.self) { try provider.physicalRows(system,state:state,supplied:forgedIdentity,policy:GeometricPhysicalFixtures.policy(),work:&work) }
        let wrongRows=VelocityConstraintSample(layout:system.layout,rowIDs:[92],rows:sample.velocity.rows,drift:sample.velocity.drift,accelerationBias:sample.velocity.accelerationBias,isIntegrable:true)
        let forgedRows=HolonomicGeometrySample(source:state,snapshot:sample.snapshot,metadata:sample.metadata,values:sample.values,velocity:wrongRows)
        #expect(throws:GeometricConstraintError.self) { try provider.physicalRows(system,state:state,supplied:forgedRows,policy:GeometricPhysicalFixtures.policy(),work:&work) }
        let outside=try GeometricFixtures.state(state,time:6)
        let outsideSample=HolonomicGeometrySample(source:outside,snapshot:sample.snapshot,metadata:sample.metadata,values:sample.values,velocity:sample.velocity)
        #expect(throws:GeometricConstraintError.self) { try provider.physicalRows(system,state:outside,supplied:outsideSample,policy:GeometricPhysicalFixtures.policy(),work:&work) }
        #expect(throws:GeometricConstraintError.self) { try provider.physicalRows(system,state:state,supplied:sample,policy:GeometricPhysicalFixtures.policy(cancelled:true),work:&work) }
        #expect(throws:GeometricConstraintError.self) { try provider.physicalRows(system,state:state,supplied:sample,policy:GeometricPhysicalFixtures.policy(bodies:1),work:&work) }
        var zero=try GeometricFixtures.work(storage:0)
        #expect(throws:GeometricConstraintError.self) { try provider.physicalRows(system,state:state,supplied:sample,policy:GeometricPhysicalFixtures.policy(),work:&zero) }
        zero=try GeometricFixtures.work(operations:0)
        #expect(throws:GeometricConstraintError.self) { try provider.physicalRows(system,state:state,supplied:sample,policy:GeometricPhysicalFixtures.policy(),work:&zero) }
        #expect(throws:GeometricConstraintError.self) { try GeometricPhysicalRowPolicy(evaluation:GeometricFixtures.evaluation(),maximumBodies:3,originalComparisonTolerance:.nan,projectionTolerance:NumericalTolerance(absolute:0,relative:0)) }
        let valid=try witness(system)
        #expect(throws:GeometricConstraintError.self) { try GeometricPhysicalRowAcceptance.validated(valid,system:system,state:changedTime,policy:GeometricPhysicalFixtures.policy(),work:&work) }
    }
    @Test func unsupportedPhysicalSupportDoesNotRemoveExistingKinematics() throws {
        let model=try GeometricPhysicalFixtures.sliders(planar:false),base=try GeometricPhysicalFixtures.distance()
        let targets=try [GeometricAnalyticTarget(value:Vector3(0.1,0,0)),GeometricAnalyticTarget(rate:Vector3(0.1,0,0))]
        var work=try GeometricFixtures.work()
        for target in targets {
            let relation=try GeometricRelation(kind:.coincidence,rowIDs:[1,2,3],first:base.first,second:base.second,target:target,scale:1)
            let system=try GeometricFixtures.system(model,rows:[relation]),state=model.descriptor.initialState
            let sample=try GeometricRelationEvaluator().evaluate(system,state:state,policy:GeometricFixtures.evaluation(),work:&work)
            #expect(sample.values.count == 3)
            #expect(throws:GeometricConstraintError.self) { try GeometricRelationEvaluator().physicalRows(system,state:state,supplied:sample,policy:GeometricPhysicalFixtures.policy(),work:&work) }
        }
        let ground=try GeometricFrameEndpoint(body:GeometricFixtures.id(.body,"ground"),frame:GeometricFixtures.id(.frame,"ground"))
        let support=try GeometricRelation(kind:.distance,rowIDs:[1],first:ground,second:base.second,target:GeometricAnalyticTarget(value:Vector3(2,0,0)),scale:1)
        let system=try GeometricFixtures.system(model,rows:[support]),state=model.descriptor.initialState
        let sample=try GeometricRelationEvaluator().evaluate(system,state:state,policy:GeometricFixtures.evaluation(),work:&work)
        #expect(throws:GeometricConstraintError.self) { try GeometricRelationEvaluator().physicalRows(system,state:state,supplied:sample,policy:GeometricPhysicalFixtures.policy(),work:&work) }
        let prescribed=try PrescribedGeometryFixture(),moving=try prescribed.system(alignment:false)
        let movingState=try prescribed.state(time:0.2,q:[0.35],v:[0.7],acceleration:[0.4])
        let movingSample=try GeometricRelationEvaluator().evaluate(moving,state:movingState,policy:GeometricFixtures.evaluation(),work:&work)
        #expect(movingSample.values.count == 3)
        #expect(throws:GeometricConstraintError.self) { try GeometricRelationEvaluator().physicalRows(moving,state:movingState,supplied:movingSample,policy:GeometricPhysicalFixtures.policy(),work:&work) }
    }
}
