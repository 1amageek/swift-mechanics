import SwiftMechanics

internal struct PrescribedGeometryFixture {
    let model:CompiledMechanicalModel
    let program:PrescribedMotionProgram
    let endpoint:GeometricFrameEndpoint
    let anchor:GeometricFrameEndpoint
    init(spherical:Bool=false) throws {
        let id=GeometricFixtures.id,pinned=try GeometricFixtures.pose(0.2,-0.1,0.4)
        let policy=try PrescribedMotionPolicy(maximumSamples:2,maximumIdentifierBytes:100,maximumMetadataBytes:2000)
        let law=try AnalyticPrescribedMotion(frame:id(.frame,"moving-parent"),parentFrame:id(.frame,"ground"),referenceTime:0,initialPose:pinned,
            translationRate:Vector3(0.6,0.1,0),translationAcceleration:Vector3(0.3,-0.1,0),rotationAxis:.unitZ,
            angularRate:0.5,angularAcceleration:0.2,minimumTime:-2,maximumTime:2,maximumIdentifierBytes:100)
        var work=try GeometricFixtures.work();program=try PrescribedMotionProgram(motions:[law],policy:policy,work:&work)
        let samples=try AnalyticPrescribedMotionSampler().sample(program,time:0,policy:policy,work:&work).anchors
        let bridge=try JointRecord(id:id(.joint,"bridge"),parentBody:id(.body,"ground"),childBody:id(.body,"base"),
            parentAnchor:JointAnchor(frame:id(.frame,"moving-parent"),placement:.prescribed),
            childAnchor:JointAnchor(frame:id(.frame,"bridge-child"),placement:.fixed(.identity)),manifold:JointManifold(.fixed))
        let joint=try GeometricFixtures.joint("rotor",parent:"base",child:"rotor",specification:spherical ? .spherical : .revolute(axis:.unitZ))
        model=try GeometricFixtures.compile(names:["ground","base","rotor"],poses:[.identity,pinned,pinned],joints:[bridge,joint],
            q:spherical ? [1,0,0,0] : [0],v:spherical ? [0,0,0.7] : [0.7],prescribed:samples,modes:[.static,.prescribedKinematic,.dynamic])
        endpoint=try GeometricFrameEndpoint(body:id(.body,"rotor"),frame:id(.frame,"rotor"),point:.unitX,axis:.unitX)
        anchor=try GeometricFrameEndpoint(body:id(.body,"ground"),frame:id(.frame,"moving-parent"),point:.unitX,axis:.unitX)
    }
    func system(alignment:Bool) throws -> GeometricConstraintSystem {
        var work=try GeometricFixtures.work()
        return try GeometricConstraintSystem(model:model,layout:GeometricFixtures.layout(model),
            relations:[GeometricRelation(kind:alignment ? .alignedAxes : .coincidence,rowIDs:alignment ? [101,102] : [101,102,103],first:endpoint,second:anchor,target:GeometricAnalyticTarget(),scale:1)],
            minimumPosition:[Double](repeating:-10,count:model.tree.layout.positionCount),maximumPosition:[Double](repeating:10,count:model.tree.layout.positionCount),minimumTime:-2,maximumTime:2,
            capacity:GeometricConstraintCapacity(maximumBodies:8,maximumPositions:8,maximumVelocities:8,maximumRows:8,maximumMetadataBytes:30000),work:&work,prescribedMotion:program)
    }
    func state(time:Double,q:[Double],v:[Double],acceleration:[Double]) throws -> KinematicState {
        var work=try GeometricFixtures.work()
        let samples=try AnalyticPrescribedMotionSampler().sample(program,time:time,policy:program.policy,work:&work)
        return try KinematicState(revision:1,time:time,q:q,v:v,acceleration:acceleration,prescribedAnchors:samples.anchors)
    }
}
