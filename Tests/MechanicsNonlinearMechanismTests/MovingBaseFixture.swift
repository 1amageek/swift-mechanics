import SwiftMechanics
import Foundation

/// Two coincident rotor tips close a real moving-base loop and share applied torque through reactions.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct MovingBaseFixture {
    let model:CompiledMechanicalModel
    let program:PrescribedMotionProgram
    let geometry:GeometricConstraintSystem
    let first:Int
    let second:Int
    let firstVelocity:Int
    let secondVelocity:Int
    let spherical:Bool
    init(angularAcceleration:Double = 0.2,spherical:Bool=false) throws {
        self.spherical=spherical
        let baseline=try NonlinearMechanismFixtures.model(),id=GeometricEvolutionFixtures.id
        let anchor=try id(.frame,"moving-anchor"),rootFrame=try id(.frame,"ground-frame")
        let policy=try PrescribedMotionPolicy(maximumSamples:4,maximumIdentifierBytes:100,maximumMetadataBytes:4000)
        let initialPose=RigidTransform(rotation:try UnitQuaternion(axis:.unitZ,angle:0.4).negated(),translation:try Vector3(0.2,-0.1,0))
        let motion=try AnalyticPrescribedMotion(frame:anchor,parentFrame:rootFrame,referenceTime:0,initialPose:initialPose,
            translationRate:Vector3(0.6,0.1,0),translationAcceleration:Vector3(0.3,-0.1,0),rotationAxis:.unitZ,
            angularRate:0.4,angularAcceleration:angularAcceleration,minimumTime:0,maximumTime:20,maximumIdentifierBytes:100)
        var work=try GeometricEvolutionFixtures.work()
        program=try PrescribedMotionProgram(motions:[motion],policy:policy,work:&work)
        let samples=try AnalyticPrescribedMotionSampler().sample(program,time:0,policy:policy,work:&work).anchors
        let bridge=try JointRecord(id:id(.joint,"bridge"),parentBody:id(.body,"ground"),childBody:id(.body,"base"),
            parentAnchor:JointAnchor(frame:anchor,placement:.prescribed),childAnchor:JointAnchor(frame:id(.frame,"bridge-child"),placement:.fixed(.identity)),manifold:JointManifold(.fixed))
        let a=try GeometricEvolutionFixtures.joint("a",parent:"base",child:"a",specification:spherical ? .spherical : .revolute(axis:.unitZ))
        let b=try GeometricEvolutionFixtures.joint("b",parent:"base",child:"b",specification:spherical ? .spherical : .revolute(axis:.unitZ))
        guard case .spatial(let source)=baseline.descriptor.bodies[0],let inertia=source.inertia else { throw GeometricConstraintError.invalidInput }
        let raw=try ["ground","base","a","b"].enumerated().map { index,key in
            try BodyRecord3D(id:id(.body,key),frame:id(.frame,key+"-frame"),mode:index == 0 ? .static : (index == 1 ? .prescribedKinematic : .dynamic),
                bodyToWorld:.identity,representations:BodyRepresentations(),inertia:inertia)
        }
        let tree=try KinematicTree(bodies:raw.map { KinematicBody(body:$0) },joints:[a,b,bridge],root:id(.body,"ground"),rootBase:.fixed,
            worldFrame:id(.frame,"world"),revision:1,capacity:baseline.policy.kinematicCapacity)
        let ea=try Self.requireEntry(tree,"a"),eb=try Self.requireEntry(tree,"b")
        first=ea.positions.start;second=eb.positions.start;firstVelocity=ea.velocities.start;secondVelocity=eb.velocities.start
        var q=[Double](repeating:0,count:tree.layout.positionCount),v=[Double](repeating:0,count:tree.layout.velocityCount)
        if spherical {
            let rotation=try UnitQuaternion(axis:.unitZ,angle:0.3)
            for entry in [ea,eb] { for (i,value) in zip(entry.positions.range,[rotation.w,rotation.x,rotation.y,rotation.z]) { q[i]=value };v[entry.velocities.start+2]=0.1 }
        } else { q[first]=0.3;q[second]=0.3;v[ea.velocities.start]=0.1;v[eb.velocities.start]=0.1 }
        let initial=try KinematicState(revision:1,time:0,q:q,v:v,acceleration:[Double](repeating:0,count:v.count),prescribedAnchors:samples)
        let snapshot=try TreeKinematicsEvaluator().evaluate(tree,state:initial,policy:baseline.policy.jointPolicy)
        let bodies=try raw.map { body in
            MechanicalBody.spatial(try BodyRecord3D(id:body.id,frame:body.frame,mode:body.mode,bodyToWorld:snapshot.body(body.id).motion.pose,
                representations:body.representations,inertia:body.inertia))
        }
        let descriptor=try MechanicalDescriptor(identity:"moving-two-rotor-loop",revision:1,bodies:bodies,
            joints:[MechanicalJoint(record:a,authority:.dynamicState),MechanicalJoint(record:b,authority:.dynamicState),MechanicalJoint(record:bridge,authority:.fixed)],
            root:id(.body,"ground"),rootBase:.fixed,rootAuthority:.fixed,worldFrame:id(.frame,"world"),initialState:initial,
            representationRequirements:[],features:[],extensions:[])
        model=try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:baseline.policy)
        let firstEndpoint=try GeometricFrameEndpoint(body:id(.body,"a"),frame:id(.frame,"a-frame"),point:.unitX,axis:.unitX)
        let secondEndpoint=try GeometricFrameEndpoint(body:id(.body,"b"),frame:id(.frame,"b-frame"),point:.unitX,axis:.unitX)
        geometry=try GeometricConstraintSystem(model:model,layout:GeometricEvolutionFixtures.layout(model),
            relations:[GeometricRelation(kind:.alignedAxes,rowIDs:[901,902],first:firstEndpoint,second:secondEndpoint,target:GeometricAnalyticTarget(),scale:1)],
            minimumPosition:[Double](repeating:-100,count:q.count),maximumPosition:[Double](repeating:100,count:q.count),minimumTime:0,maximumTime:20,
            capacity:GeometricConstraintCapacity(maximumBodies:8,maximumPositions:8,maximumVelocities:8,maximumRows:8,maximumMetadataBytes:30000),work:&work,prescribedMotion:program)
    }
    private static func requireEntry(_ tree:KinematicTree,_ key:String) throws -> JointCoordinateLayout {
        guard let value=tree.layout.joints.first(where:{$0.joint.key == key}) else { throw GeometricConstraintError.staleSource };return value
    }
    func kinetic(time:Double,velocity:Double) -> Double {
        let vx=0.6+0.3*time,vy=0.1-0.1*time,w=0.4+program.motions[0].angularAcceleration*time
        return 1.5*(vx*vx+vy*vy)+0.5*w*w+(w+velocity)*(w+velocity)
    }
    func prescribedPower(time:Double,torque:Double) -> Double {
        let alpha=program.motions[0].angularAcceleration,w=0.4+alpha*time
        return 3*((0.6+0.3*time)*0.3-(0.1-0.1*time)*0.1)+(alpha+torque)*w
    }
    func equation(torque:Double = 0.8,sampler:any PrescribedMotionSampling = AnalyticPrescribedMotionSampler(),kernel:any RigidEquationComputing = RigidEquationKernel()) throws -> GeometricMechanismEquation {
        var drive=[Double](repeating:0,count:model.tree.layout.velocityCount);drive[firstVelocity+(spherical ? 2 : 0)]=torque
        let base=try GeometricEvolutionFixtures.equation(geometry,drive:drive)
        return try GeometricMechanismEquation(identity:base.descriptor.identity,geometry:geometry,drive:base.drive,policy:base.policy,projection:base.projection,
            maximumStageChartCorrection:base.maximumStageChartCorrection,publicationBudget:base.publicationBudget,
            admission:NonlinearMechanismFixtures.admission(),maximumIdentityBytes:50000,kernel:kernel,motionSampler:sampler)
    }
}

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
extension MovingBaseFixture {
    typealias Session=RuntimeSession<GeometricMechanismCheckpointHandler>
    func session(_ equation:GeometricMechanismEquation,step:Double=0.05) throws -> (Session,IntegrationContinuationProvider) {
        let (temporary,continuation)=try NonlinearMechanismFixtures.session(equation,step:step)
        let configuration=temporary.configuration;_ = temporary.shutdown()
        let base=ReferenceRuntimeCheckpointHandler(contributors:continuation,revisions:ReferenceModelRevisionUpdater())
        let handler=try GeometricMechanismCheckpointHandler(equations:equation,continuation:continuation,base:base,validationBudget:equation.publicationBudget)
        let initial=model.descriptor.initialState
        return (try Session(model:model,configuration:configuration,initialState:initial,
            contributors:[continuation.initialRecord(physical:initial,equations:equation)],seed:42,checkpoints:handler),continuation)
    }
}
