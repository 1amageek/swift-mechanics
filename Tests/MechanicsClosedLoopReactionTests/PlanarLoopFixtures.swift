import SwiftMechanics
import Foundation

internal enum PlanarLoopFixtures {
    static func rank(_ n:Int) throws->ConstraintSolvePolicy {
        let base=try LoopFixtures.rankPolicy()
        return try ConstraintSolvePolicy(evaluation:base.evaluation,diagonalMetric:[Double](repeating:1,count:n),energyScale:base.energyScale,
            rankPolicy:.allowRedundancy,rankRelativeTolerance:base.rankRelativeTolerance,originalResidualTolerance:base.originalResidualTolerance,
            maximumCorrection:base.maximumCorrection,nonlinear:base.nonlinear,
            linearCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),linearTolerance:base.linearTolerance)
    }
    static func mechanismPolicy(_ layout:ConstraintCoordinateLayout) throws->MechanismSolvePolicy {
        let base=try LoopFixtures.mechanismPolicy().dynamics
        return try MechanismSolvePolicy(dynamics:DynamicsSolvePolicy(capability:base.capability,linearTolerance:base.linearTolerance,
            coordinateScales:layout.scales,energyScale:base.energyScale,timeScale:layout.timeScale),constraints:rank(layout.scales.count),
            maximumCoordinates:12,maximumRows:12,originalTolerance:1e-9)
    }
    static func policy(_ n:Int,rows:Int=12,cancelled:Bool=false) throws->ClosedLoopReactionPolicy {
        let tolerance=try LoopFixtures.tolerance()
        return try ClosedLoopReactionPolicy(maximumRows:rows,geometry:LoopFixtures.rowPolicy(),rank:rank(n),
            tree:TreeReactionPolicy(maximumBodies:8,maximumJoints:8,maximumBodyLoads:40,generalizedForceScales:[Double](repeating:1,count:n),
                generalizedTolerance:tolerance,forceTolerance:tolerance,torqueTolerance:tolerance,isCancelled:{cancelled}),admission:LoopFixtures.admission(),
            positionTolerance:1e-9,velocityTolerance:1e-9,accelerationTolerance:1e-9)
    }
    static func fourbarModel(angle:Double = .pi/2,mass:Double=1) throws->CompiledMechanicalModel {
        let names=["ground","crank","rocker","coupler"]
        let x=[0.0,0,2,cos(angle)],y=[0.0,0,0,sin(angle)],angles=[0.0,angle,angle,0]
        var bodies:[MechanicalBody]=[]
        for i in names.indices {
            bodies.append(.planar(try BodyRecord2D(id:LoopFixtures.id(.body,names[i]),frame:LoopFixtures.id(.frame,names[i]),mode:i == 0 ? .static : .dynamic,
                bodyToWorld:PlanarPose(x:x[i],y:y[i],angle:angles[i]),representations:BodyRepresentations(),
                inertia:InertialRepresentation2D(properties:MassProperties2D(mass:mass,centerX:0,centerY:0,polarInertiaAtCenter:1),
                    provenance:SourceProvenance(source:"planar-loop-independent",revision:1),quality:.exact))))
        }
        var joints:[JointRecord]=[]
        for (key,parent,child,point) in [("a","ground","crank",Vector3.zero),("c","ground","rocker",try Vector3(2,0,0)),("b","crank","coupler",Vector3.unitX)] {
            joints.append(try JointRecord(id:LoopFixtures.id(.joint,key),parentBody:LoopFixtures.id(.body,parent),childBody:LoopFixtures.id(.body,child),
                parentAnchor:JointAnchor(frame:LoopFixtures.id(.frame,key+"-parent"),placement:.fixed(RigidTransform(rotation:.identity,translation:point))),
                childAnchor:JointAnchor(frame:LoopFixtures.id(.frame,key+"-child"),placement:.fixed(.identity)),manifold:JointManifold(.revolute(axis:.unitZ))))
        }
        let tree=try KinematicTree(bodies:bodies.map { try $0.kinematicBody() },joints:joints,root:LoopFixtures.id(.body,"ground"),rootBase:.fixed,
            worldFrame:LoopFixtures.id(.frame,"world"),revision:1,capacity:KinematicCapacity(maximumBodies:8,maximumVelocities:12,maximumJacobianScalars:3000))
        var q=[Double](repeating:0,count:3)
        for entry in tree.layout.joints { q[entry.positions.start]=entry.joint.key == "b" ? -angle : angle }
        let state=try KinematicState(revision:1,time:0,q:q,v:[0,0,0],acceleration:[0,0,0])
        let descriptor=try MechanicalDescriptor(identity:"planar-loop-independent",revision:1,bodies:bodies,joints:joints.map { MechanicalJoint(record:$0,authority:.dynamicState) },
            root:LoopFixtures.id(.body,"ground"),rootBase:.fixed,rootAuthority:.fixed,worldFrame:tree.worldFrame,initialState:state,
            representationRequirements:[],features:[],extensions:[])
        let compiler:any MechanicalModelCompiling=ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions())
        return try compiler.compile(descriptor,policy:LoopFixtures.model(planar:true).policy)
    }
    static func fourbarGeometry(_ model:CompiledMechanicalModel,scale:Double=2,duplicate:Bool=false) throws->GeometricConstraintSystem {
        let first=try GeometricFrameEndpoint(body:LoopFixtures.id(.body,"coupler"),frame:LoopFixtures.id(.frame,"coupler"),point:Vector3(2,0,0))
        let second=try GeometricFrameEndpoint(body:LoopFixtures.id(.body,"rocker"),frame:LoopFixtures.id(.frame,"rocker"),point:.unitX)
        var relations=[try GeometricRelation(kind:.coincidence,rowIDs:[11,12,13],first:first,second:second,target:GeometricAnalyticTarget(),scale:scale)]
        if duplicate { relations.append(try GeometricRelation(kind:.coincidence,rowIDs:[21,22,23],first:first,second:second,target:GeometricAnalyticTarget(),scale:scale)) }
        let layout=try ConstraintCoordinateLayout(coordinateIDs:[1,2,3],dimensions:[.angle,.angle,.angle],scales:[1,1,1],timeScale:5,revision:1)
        var work=try LoopFixtures.work()
        return try GeometricConstraintSystem(model:model,layout:layout,relations:relations,minimumPosition:[-20,-20,-20],maximumPosition:[20,20,20],minimumTime:-5,maximumTime:5,
            capacity:GeometricConstraintCapacity(maximumBodies:8,maximumPositions:12,maximumVelocities:12,maximumRows:12,maximumMetadataBytes:30000),work:&work)
    }
    static func allocation(_ geometry:GeometricConstraintSystem,_ rows:GeometricPhysicalRowWitness,state:KinematicState?=nil) throws->GeometricPhysicalAllocationWitness {
        var work=try LoopFixtures.work()
        let producer:any GeometricPhysicalAllocationProviding=GeometricPhysicalAllocationEvaluator()
        return try producer.physicalAllocation(geometry,state:state ?? geometry.model.descriptor.initialState,supplied:rows,
            policy:GeometricPhysicalAllocationPolicy(rows:LoopFixtures.rowPolicy(),rank:rank(geometry.layout.scales.count)),work:&work)
    }
    static func system(_ model:CompiledMechanicalModel,state suppliedState:KinematicState?=nil,force:Double=10,offset:Bool=false,gravity:Bool=false,generalized:Bool=false) throws->PhysicalRigidDynamicsSystem {
        let state=suppliedState ?? model.descriptor.initialState,snapshot=try model.evaluate(model.makeState(state))
        var inertias:[PlanarRigidBodyInertia]=[]
        for body in snapshot.tree.bodies {
            guard let record=model.descriptor.bodies.first(where:{$0.id == body.id}),case .planar(let planar)=record,let inertia=planar.inertia else { throw DynamicsError.invalidInput }
            inertias.append(try PlanarRigidBodyInertia(body:body.id,frame:body.frame,properties:inertia.properties))
        }
        let fourbar=model.tree.bodies.count == 4
        let load=try BodyWrenchContribution(body:LoopFixtures.id(.body,fourbar ? "crank" : "first"),frame:snapshot.tree.worldFrame,
            referencePoint:offset ? .unitY : .zero,
            wrench:SpatialWrench(torque:fourbar ? .unitZ : .zero,force:fourbar || generalized ? .zero : Vector3(force,offset ? 5 : 0,0)),channel:.applied)
        let drives=generalized ? [try GeneralizedForceContribution(values:[force,0],channel:.actuator)] : []
        let original=try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:state.v,inertias:inertias,
            gravity:gravity ? AffineGravity(frame:snapshot.tree.worldFrame,accelerationAtOrigin:Vector3(0,-10,0)) : nil,bodyWrenches:[load],generalizedForces:drives)
        var work=try LoopFixtures.work(),loads=try LoopFixtures.loads()
        let equations:any PhysicalRigidEquationComputing=RigidEquationKernel()
        return try equations.assemble(PhysicalRigidDynamicsInput(planar:original),admission:LoopFixtures.admission(),loadWork:&loads,work:&work)
    }
    static func motion(_ system:PhysicalRigidDynamicsSystem,_ rows:GeometricPhysicalRowWitness,drive:[Double]?=nil,impulse:Bool=false) throws->PhysicalConstrainedMotion {
        var work=try LoopFixtures.work(),dynamics=try LoopFixtures.work(),rank=try LoopFixtures.work(),linear=try LoopFixtures.work()
        let solver:any PhysicalConstrainedMechanismSolving=MassWeightedMechanismSolver(physicalDynamics:DenseRigidDynamics(physicalEquations:RigidEquationKernel()),physicalEquations:RigidEquationKernel())
        let policy=try mechanismPolicy(rows.original.velocity.layout)
        if impulse { return try solver.reconcileVelocity(system,sample:rows.original.velocity,policy:policy,work:&work,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear) }
        return try solver.acceleration(system,sample:rows.original.velocity,drive:drive ?? [Double](repeating:0,count:system.velocityCount),policy:policy,
            work:&work,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear)
    }
    static func input(fourbar:Bool=true,scale:Double?=nil,offset:Bool=false,gravity:Bool=false) throws->PlanarClosedLoopReactionInput {
        let model=try fourbar ? fourbarModel() : LoopFixtures.model(offset:offset,planar:true)
        let geometry=try fourbar ? fourbarGeometry(model,scale:scale ?? 2) : LoopFixtures.geometry(model,scale:scale ?? 4,offset:offset)
        let rows=try LoopFixtures.rows(geometry,state:model.descriptor.initialState),system=try self.system(model,offset:offset,gravity:gravity)
        return PlanarClosedLoopReactionInput(motion:try motion(system,rows),geometry:geometry,state:model.descriptor.initialState,
            allocation:try allocation(geometry,rows),originalDrive:[Double](repeating:0,count:system.velocityCount),topology:.completeTreeAndDeclaredRows)
    }
    static func replacing(_ input:PlanarClosedLoopReactionInput,motion:PhysicalConstrainedMotion?=nil,geometry:GeometricConstraintSystem?=nil,state:KinematicState?=nil,
                          allocation:GeometricPhysicalAllocationWitness?=nil,drive:[Double]?=nil,topology:ClosedLoopReactionTopology?=nil)->PlanarClosedLoopReactionInput {
        PlanarClosedLoopReactionInput(motion:motion ?? input.motion,geometry:geometry ?? input.geometry,state:state ?? input.state,
            allocation:allocation ?? input.allocation,originalDrive:drive ?? input.originalDrive,topology:topology ?? input.topology)
    }
}
