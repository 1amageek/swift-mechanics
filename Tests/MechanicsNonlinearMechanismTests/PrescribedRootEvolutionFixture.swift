import SwiftMechanics
import Foundation

/// Compiled prescribed root with optional genuinely coupled dynamic rotors.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct PrescribedRootEvolutionFixture {
    let model:CompiledMechanicalModel
    let program:PrescribedBaseMotionProgram
    let geometry:GeometricConstraintSystem
    let planar:Bool
    let descendants:Bool
    let first:Int
    let second:Int
    init(planar:Bool,descendants:Bool = false,polarScale:Double = 1,maximumTime:Double = 2) throws {
        self.planar=planar;self.descendants=descendants
        let id=GeometricEvolutionFixtures.id,baseline=try NonlinearMechanismFixtures.model()
        let rootFrame=try id(.frame,"root-frame"),world=try id(.frame,"world")
        let rotation=try UnitQuaternion(axis:descendants || planar ? .unitZ : .unitX,angle:0.4)
        let pose=RigidTransform(rotation:rotation,translation:try Vector3(1,2,planar ? 0 : 3))
        let law=try AnalyticPrescribedMotion(frame:rootFrame,parentFrame:world,referenceTime:0,initialPose:pose,
            translationRate:Vector3(0.4,-0.2,planar ? 0 : 0.1),translationAcceleration:Vector3(0.3,0.2,planar ? 0 : -0.1),
            rotationAxis:.unitZ,angularRate:0.2,angularAcceleration:0.3,minimumTime:0,maximumTime:maximumTime,maximumIdentifierBytes:100)
        let motionPolicy=try PrescribedMotionPolicy(maximumSamples:1,maximumIdentifierBytes:100,maximumMetadataBytes:6000)
        var work=try GeometricEvolutionFixtures.work()
        let base=planar ? BaseLayout.planarFloating : .spatialFloating
        program=try PrescribedBaseMotionProgram(law:law,layout:base,policy:motionPolicy,work:&work)
        let initialBase=try AnalyticPrescribedBaseMotionSampler().sampleBase(program,time:0,policy:motionPolicy,work:&work)
        let names=descendants ? ["root","a","b"] : ["root"]
        func record(_ key:String,_ bodyPose:RigidTransform) throws -> MechanicalBody {
            let polar=descendants ? (key == "root" ? 2.0 : (key == "a" ? 2 : 3)) : 5
            let mass=key == "root" ? 2.0 : 1.0
            let x=descendants ? 0.0 : 0.4,y=descendants ? 0.0 : -0.3,z=descendants || planar ? 0.0 : 0.2
            let provenance=try SourceProvenance(source:"prescribed-root-physical",revision:1)
            if planar {
                return .planar(try BodyRecord2D(id:id(.body,key),frame:id(.frame,key+"-frame"),mode:.dynamic,
                    bodyToWorld:PlanarPose(x:bodyPose.translation.x,y:bodyPose.translation.y,angle:2*atan2(bodyPose.rotation.z,bodyPose.rotation.w)),
                    representations:BodyRepresentations(),inertia:InertialRepresentation2D(properties:MassProperties2D(mass:mass,centerX:x,centerY:y,polarInertiaAtCenter:polar*polarScale),provenance:provenance,quality:.exact)))
            }
            return .spatial(try BodyRecord3D(id:id(.body,key),frame:id(.frame,key+"-frame"),mode:.dynamic,bodyToWorld:bodyPose,
                representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:MassProperties3D(mass:mass,centerOfMass:Vector3(x,y,z),
                    inertiaAtCenter:Matrix3(3*polarScale,0,0,0,4*polarScale,0,0,0,polar*polarScale),policy:baseline.policy.inertiaPolicy),provenance:provenance,quality:.exact)))
        }
        let joints=descendants ? [try GeometricEvolutionFixtures.joint("a",parent:"root",child:"a",specification:.revolute(axis:.unitZ)),
                                  try GeometricEvolutionFixtures.joint("b",parent:"root",child:"b",specification:.revolute(axis:.unitZ))] : []
        let raw=try names.map { try record($0,pose) }
        let tree=try KinematicTree(bodies:raw.map { try $0.kinematicBody() },joints:joints,root:id(.body,"root"),rootBase:base,worldFrame:world,revision:1,capacity:baseline.policy.kinematicCapacity)
        first=tree.layout.joints.first(where:{$0.joint.key == "a"})?.velocities.start ?? -1
        second=tree.layout.joints.first(where:{$0.joint.key == "b"})?.velocities.start ?? -1
        let q=initialBase.q+(descendants ? [0.3,0.3] : []),v=initialBase.v+(descendants ? [0.1,0.1] : [])
        let initial=try KinematicState(revision:1,time:0,q:q,v:v,acceleration:initialBase.a+(descendants ? [-0.1,-0.1] : []))
        let snapshot=try TreeKinematicsEvaluator().evaluate(tree,state:initial,policy:baseline.policy.jointPolicy)
        let bodies=try names.map { try record($0,snapshot.body(id(.body,$0)).motion.pose) }
        let descriptor=try MechanicalDescriptor(identity:planar ? "prescribed-planar-root" : "prescribed-spatial-root",revision:1,bodies:bodies,
            joints:joints.map { MechanicalJoint(record:$0,authority:.dynamicState) },root:id(.body,"root"),rootBase:base,rootAuthority:.prescribedMotion,
            worldFrame:world,initialState:initial,representationRequirements:[],features:[],extensions:[])
        model=try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:baseline.policy)
        let dimensions:[PhysicalDimension]=(planar ? [.length,.length,.angle] : [.length,.length,.length,.angle,.angle,.angle])+(descendants ? [.angle,.angle] : [])
        let layout=try ConstraintCoordinateLayout(coordinateIDs:dimensions.indices.map { UInt64($0+1) },dimensions:dimensions,scales:[Double](repeating:1,count:dimensions.count),timeScale:3,revision:1)
        var relations:[GeometricRelation]=[]
        if descendants {
            let a=try GeometricFrameEndpoint(body:id(.body,"a"),frame:id(.frame,"a-frame"),axis:.unitX)
            let b=try GeometricFrameEndpoint(body:id(.body,"b"),frame:id(.frame,"b-frame"),axis:.unitX)
            relations=[try GeometricRelation(kind:.alignedAxes,rowIDs:[41,42],first:a,second:b,target:GeometricAnalyticTarget(),scale:1)]
        }
        geometry=try GeometricConstraintSystem(model:model,layout:layout,relations:relations,minimumPosition:[Double](repeating:-100,count:q.count),
            maximumPosition:[Double](repeating:100,count:q.count),minimumTime:0,maximumTime:maximumTime,
            capacity:GeometricConstraintCapacity(maximumBodies:8,maximumPositions:16,maximumVelocities:8,maximumRows:12,maximumMetadataBytes:50000),work:&work,prescribedBase:program)
    }
    func equation(kernel:any PhysicalRigidEquationComputing = RigidEquationKernel(),sampler:any PrescribedBaseMotionSampling = AnalyticPrescribedBaseMotionSampler(),
                  partitioner:any PhysicalPowerPartitioning = RigidEquationKernel(),solver:any PrescribedRootMechanismSolving = MassWeightedMechanismSolver(
                    physicalDynamics:DenseRigidDynamics(physicalEquations:RigidEquationKernel()),physicalEquations:RigidEquationKernel())) throws -> GeometricMechanismEquation {
        let n=geometry.layout.scales.count,projection=try GeometricEvolutionFixtures.policy(n)
        let baseline=try NonlinearMechanismFixtures.policy(scales:geometry.layout.scales,gramLU:true)
        let dynamics=try DynamicsSolvePolicy(capability:baseline.dynamics.capability,linearTolerance:baseline.dynamics.linearTolerance,
            coordinateScales:geometry.layout.scales,energyScale:7,timeScale:3)
        let policy=try MechanismSolvePolicy(dynamics:dynamics,constraints:projection.constraints,maximumCoordinates:8,maximumRows:12,originalTolerance:1e-8)
        var drive=[Double](repeating:0,count:n);if descendants { drive[first]=1 }
        return try GeometricMechanismEquation(identity:"prescribed-root-evolution",geometry:geometry,drive:drive,policy:policy,projection:projection,
            maximumStageChartCorrection:0.01,publicationBudget:GeometricEvolutionFixtures.work().budget,admission:NonlinearMechanismFixtures.admission(),maximumIdentityBytes:100000,
            physicalKernel:kernel,prescribedRootSolver:solver,activeRanker:WeightedConstraintAssembler(),baseSampler:sampler,powerPartitioner:partitioner)
    }
    func sample(_ time:Double) throws -> PrescribedBaseMotionSample {
        var work=try GeometricEvolutionFixtures.work()
        return try AnalyticPrescribedBaseMotionSampler().sampleBase(program,time:time,policy:program.policy,work:&work)
    }
    func session(_ equation:GeometricMechanismEquation,step:Double=0.02) throws -> (PlanarEvolutionFixtures.Session,IntegrationContinuationProvider) {
        try PlanarEvolutionFixtures.session(equation,step:step)
    }
}
