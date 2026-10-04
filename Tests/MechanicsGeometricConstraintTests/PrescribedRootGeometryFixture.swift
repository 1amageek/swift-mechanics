import SwiftMechanics

internal struct PrescribedRootGeometryFixture {
    let model:CompiledMechanicalModel
    let program:PrescribedBaseMotionProgram
    let system:GeometricConstraintSystem
    init(planar:Bool,descendants:Bool=false,rootID:UInt64?=nil) throws {
        let id=GeometricFixtures.id,base=planar ? BaseLayout.planarFloating : .spatialFloating
        let pose=RigidTransform(rotation:try UnitQuaternion(axis:planar || descendants ? .unitZ : .unitX,angle:0.4),translation:try Vector3(1,2,0))
        let policy=try PrescribedMotionPolicy(maximumSamples:1,maximumIdentifierBytes:100,maximumMetadataBytes:6000)
        let law=try AnalyticPrescribedMotion(frame:id(.frame,"root"),parentFrame:id(.frame,"world"),referenceTime:0,initialPose:pose,
            translationRate:Vector3(0.4,-0.2,0),translationAcceleration:Vector3(0.3,0.2,0),rotationAxis:.unitZ,angularRate:0.2,angularAcceleration:0.3,
            minimumTime:0,maximumTime:2,maximumIdentifierBytes:100)
        var work=try GeometricFixtures.work()
        program=try PrescribedBaseMotionProgram(law:law,layout:base,policy:policy,work:&work)
        let sample=try AnalyticPrescribedBaseMotionSampler().sampleBase(program,time:0,policy:policy,work:&work)
        let names=descendants ? ["root","a","b"] : ["root"]
        let child=try pose.composed(with:GeometricFixtures.pose(0,0,0.3))
        let joints=descendants ? [try GeometricFixtures.joint("a",parent:"root",child:"a",specification:.revolute(axis:.unitZ)),
                                  try GeometricFixtures.joint("b",parent:"root",child:"b",specification:.revolute(axis:.unitZ))] : []
        let q=sample.q+(descendants ? [0.3,0.3] : []),v=sample.v+(descendants ? [0,0] : [])
        let original=try GeometricFixtures.compile(names:names,poses:descendants ? [pose,child,child] : [pose],joints:joints,q:q,v:v,floating:true,planar:planar)
        let d=original.descriptor,initial=try KinematicState(revision:1,time:0,q:q,v:v,acceleration:sample.a+(descendants ? [0,0] : []))
        let descriptor=try MechanicalDescriptor(identity:d.identity,revision:d.revision,bodies:d.bodies,joints:d.joints,root:d.root,rootBase:d.rootBase,
            rootAuthority:.prescribedMotion,worldFrame:d.worldFrame,initialState:initial,representationRequirements:d.representationRequirements,features:d.features,extensions:d.extensions)
        model=try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:original.policy)
        var relations:[GeometricRelation]=[]
        if descendants {
            relations=[try GeometricRelation(kind:.alignedAxes,rowIDs:[41,42],first:GeometricFrameEndpoint(body:id(.body,"a"),frame:id(.frame,"a"),axis:.unitX),
                second:GeometricFrameEndpoint(body:id(.body,"b"),frame:id(.frame,"b"),axis:.unitX),target:GeometricAnalyticTarget(),scale:1)]
        }
        let ids=rootID.map { value in (0..<base.velocityCount).map { value+UInt64($0) } } ?? []
        system=try GeometricConstraintSystem(model:model,layout:GeometricFixtures.layout(model),relations:relations,
            minimumPosition:[Double](repeating:-100,count:q.count),maximumPosition:[Double](repeating:100,count:q.count),minimumTime:0,maximumTime:2,
            capacity:GeometricConstraintCapacity(maximumBodies:8,maximumPositions:16,maximumVelocities:8,maximumRows:12,maximumMetadataBytes:50000),work:&work,prescribedBase:program,rootRowIDs:ids)
    }
}
