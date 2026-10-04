import SwiftMechanics
import Foundation

internal enum GeometricFixtures {
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func work(storage:Int = 4_000_000,operations:Int = 50_000_000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:1000))
    }
    static func pose(_ x:Double=0,_ y:Double=0,_ angle:Double=0) throws -> RigidTransform {
        RigidTransform(rotation:try UnitQuaternion(axis:.unitZ,angle:angle),translation:try Vector3(x,y,0))
    }
    static func compile(names:[String],poses:[RigidTransform],joints:[JointRecord],q:[Double],v:[Double],floating:Bool=false,jointCoordinates:[String:([Double],[Double])]?=nil,prescribed:[PrescribedAnchorState]=[],modes:[BodyMotionMode]?=nil,planar:Bool=false) throws -> CompiledMechanicalModel {
        let tolerance=try NumericalTolerance(absolute:1e-9,relative:1e-9),ip=try InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0)
        var bodies:[MechanicalBody]=[]
        for i in names.indices {
            let mode=modes?[i] ?? (i == 0 && !floating ? .static : .dynamic)
            if planar {
                let properties=try MassProperties2D(mass:1,centerX:0,centerY:0,polarInertiaAtCenter:1)
                bodies.append(.planar(try BodyRecord2D(id:id(.body,names[i]),frame:id(.frame,names[i]),mode:mode,
                    bodyToWorld:PlanarPose(x:poses[i].translation.x,y:poses[i].translation.y,angle:poses[i].rotation.rotationVector().z),
                    representations:BodyRepresentations(),inertia:InertialRepresentation2D(properties:properties,
                    provenance:SourceProvenance(source:"planar-geometry-test",revision:1),quality:.exact))))
            } else {
                let properties=try MassProperties3D(mass:1,centerOfMass:.zero,inertiaAtCenter:Matrix3(1,0,0,0,1,0,0,0,1),policy:ip)
                bodies.append(.spatial(try BodyRecord3D(id:id(.body,names[i]),frame:id(.frame,names[i]),mode:mode,
                    bodyToWorld:poses[i],representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:properties,
                    provenance:SourceProvenance(source:"geometry-test",revision:1),quality:.exact))))
            }
        }
        let base:BaseLayout = floating ? (planar ? .planarFloating : .spatialFloating) : .fixed
        let orderedJoints=joints.sorted { $0.id.key < $1.id.key }
        let tree=try KinematicTree(bodies:bodies.map { try $0.kinematicBody() },joints:orderedJoints,root:id(.body,names[0]),
            rootBase:base,worldFrame:id(.frame,"world"),revision:1,
            capacity:KinematicCapacity(maximumBodies:12,maximumVelocities:24,maximumJacobianScalars:5000))
        var position=q,velocity=v
        if let coordinates=jointCoordinates {
            position=[Double](repeating:0,count:tree.layout.positionCount);velocity=[Double](repeating:0,count:tree.layout.velocityCount)
            for i in 0..<tree.rootBase.positionCount { position[i]=q[i] }
            for i in 0..<tree.rootBase.velocityCount { velocity[i]=v[i] }
            for entry in tree.layout.joints {
                guard let values=coordinates[entry.joint.key],values.0.count == entry.positions.count,values.1.count == entry.velocities.count else { throw GeometricConstraintError.invalidShape }
                for (i,value) in zip(entry.positions.range,values.0) { position[i]=value }
                for (i,value) in zip(entry.velocities.range,values.1) { velocity[i]=value }
            }
        }
        let state=try KinematicState(revision:1,time:0,q:position,v:velocity,acceleration:[Double](repeating:0,count:velocity.count),prescribedAnchors:prescribed)
        let descriptor=try MechanicalDescriptor(identity:"geometric-fixture",revision:1,bodies:bodies,joints:orderedJoints.map { MechanicalJoint(record:$0,authority:$0.manifold.velocityCount == 0 ? .fixed : .dynamicState) },
            root:id(.body,names[0]),rootBase:base,rootAuthority:floating ? .dynamicState : .fixed,
            worldFrame:id(.frame,"world"),initialState:state,representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:12,maximumVelocities:24,maximumJacobianScalars:5000),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-10,characteristicLengthMeters:1),inertiaPolicy:ip,
            translationTolerance:tolerance,rotationTolerance:tolerance,maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:10000,
            maximumDependencyEntries:1000,maximumExtensionRecords:8,maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        let model=try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
        guard model.tree.layout == tree.layout else { throw GeometricConstraintError.staleSource }
        return model
    }
    static func joint(_ key:String,parent:String,child:String,specification:JointSpecification,parentPose:RigidTransform = .identity,childPose:RigidTransform = .identity) throws -> JointRecord {
        try JointRecord(id:id(.joint,key),parentBody:id(.body,parent),childBody:id(.body,child),
            parentAnchor:JointAnchor(frame:id(.frame,key+"-parent"),placement:.fixed(parentPose)),
            childAnchor:JointAnchor(frame:id(.frame,key+"-child"),placement:.fixed(childPose)),manifold:JointManifold(specification))
    }
    static func fourbar(angle:Double=0.6,nonidentityFrame:Bool=true,planar:Bool=false) throws -> CompiledMechanicalModel {
        let child=try nonidentityFrame ? pose(0.3,0.2,0.2) : RigidTransform.identity,a=try pose(0,0,angle),c=try pose(2,0,angle)
        let b=try pose(cos(angle),sin(angle),0).composed(with:child.inverted())
        let joints=[try joint("a",parent:"ground",child:"crank",specification:.revolute(axis:.unitZ)),
                    try joint("c",parent:"ground",child:"rocker",specification:.revolute(axis:.unitZ),parentPose:pose(2,0)),
                    try joint("b",parent:"crank",child:"coupler",specification:.revolute(axis:.unitZ),parentPose:pose(1,0),childPose:child)]
        return try compile(names:["ground","crank","rocker","coupler"],poses:[.identity,a,c,b],joints:joints,q:[],v:[],jointCoordinates:["a":([angle],[0.7]),"c":([angle],[0.7]),"b":([-angle],[-0.7])],planar:planar)
    }
    static func layout(_ model:CompiledMechanicalModel,scales:[Double]? = nil) throws -> ConstraintCoordinateLayout {
        var dimensions:[PhysicalDimension]=[]
        if model.tree.rootBase == .spatialFloating { dimensions += [.length,.length,.length,.angle,.angle,.angle] }
        if model.tree.rootBase == .planarFloating { dimensions += [.length,.length,.angle] }
        for joint in model.tree.joints {
            switch joint.manifold.kind {
            case .spherical: dimensions += [.angle,.angle,.angle]
            case .sixDOF: dimensions += [.length,.length,.length,.angle,.angle,.angle]
            default: for axis in joint.manifold.orderedAxes { dimensions.append(axis.kind == .prismatic ? .length : .angle) }
            }
        }
        return try ConstraintCoordinateLayout(coordinateIDs:dimensions.indices.map { UInt64($0+1) },dimensions:dimensions,
            scales:scales ?? [Double](repeating:1,count:dimensions.count),timeScale:3,revision:1)
    }
    static func loopRows(target:GeometricAnalyticTarget?=nil,duplicate:Bool=false) throws -> [GeometricRelation] {
        let a=try GeometricFrameEndpoint(body:id(.body,"coupler"),frame:id(.frame,"b-child"),point:Vector3(2,0,0))
        let b=try GeometricFrameEndpoint(body:id(.body,"rocker"),frame:id(.frame,"rocker"),point:Vector3(1,0,0))
        let t=try target ?? GeometricAnalyticTarget()
        var rows=[try GeometricRelation(kind:.coincidence,rowIDs:[11,12,13],first:a,second:b,target:t,scale:2)]
        if duplicate { rows.append(try GeometricRelation(kind:.coincidence,rowIDs:[21,22,23],first:a,second:b,target:t,scale:2)) }
        return rows
    }
    static func system(_ model:CompiledMechanicalModel,rows:[GeometricRelation],scales:[Double]?=nil,metadata:Int=30000) throws -> GeometricConstraintSystem {
        var work=try work()
        return try GeometricConstraintSystem(model:model,layout:layout(model,scales:scales),relations:rows,
            minimumPosition:[Double](repeating:-20,count:model.tree.layout.positionCount),maximumPosition:[Double](repeating:20,count:model.tree.layout.positionCount),minimumTime:-5,maximumTime:5,
            capacity:GeometricConstraintCapacity(maximumBodies:12,maximumPositions:24,maximumVelocities:24,maximumRows:30,maximumMetadataBytes:metadata),work:&work)
    }
    static func evaluation(cancelled:@escaping @Sendable ()->Bool = {false}) throws -> ConstraintEvaluationPolicy {
        try ConstraintEvaluationPolicy(maximumCoordinates:24,maximumRows:30,expectedLayoutRevision:1,isCancelled:cancelled)
    }
    static func policy(_ n:Int,limit:Double=5,iterations:Int=30,rank:ConstraintRankPolicy = .allowRedundancy,cancelled:@escaping @Sendable ()->Bool = {false}) throws -> ManifoldProjectionPolicy {
        let tolerance=try LinearTolerance<Double>(absoluteResidual:1e-11,relativeResidual:1e-11,pivotThreshold:1e-13)
        let nonlinear=try NonlinearPolicy<Double>(strategy:.lineSearch(contraction:0.5,sufficientDecrease:1e-4,minimumFraction:1e-7),
            capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),tolerance:tolerance,referenceScale:1,
            minimumDirectionNorm:0,derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-4,derivativeRelativeTolerance:1e-4,
            maximumFactorEntries:5000,estimateCondition:false,budget:work().budget)
        let constraints=try ConstraintSolvePolicy(evaluation:evaluation(cancelled:cancelled),diagonalMetric:(0..<n).map { 1+Double($0)/4 },energyScale:7,
            rankPolicy:rank,rankRelativeTolerance:1e-10,originalResidualTolerance:1e-9,maximumCorrection:limit,nonlinear:nonlinear,
            linearCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),linearTolerance:tolerance)
        return try ManifoldProjectionPolicy(constraints:constraints,maximumIterations:iterations,maximumPathCorrection:limit,maximumMetadataBytes:2000)
    }
    static func state(_ original:KinematicState,q:[Double]?=nil,v:[Double]?=nil,time:Double?=nil) throws -> KinematicState {
        try KinematicState(revision:original.revision,time:time ?? original.time,q:q ?? original.q,v:v ?? original.v,acceleration:original.acceleration)
    }
    static func entry(_ model:CompiledMechanicalModel,_ key:String) throws -> JointCoordinateLayout {
        guard let entry=model.tree.layout.joints.first(where:{$0.joint.key == key}) else { throw GeometricConstraintError.staleSource };return entry
    }
    static func quaternionStarts(_ model:CompiledMechanicalModel) throws -> [Int] {
        var starts:[Int]=model.tree.rootBase == .spatialFloating ? [3] : []
        for joint in model.tree.joints {
            let layout=try entry(model,joint.id.key)
            if joint.manifold.kind == .spherical { starts.append(layout.positions.start) }
            if joint.manifold.kind == .sixDOF { starts.append(layout.positions.start+3) }
        }
        return starts
    }
    static func mixed() throws -> CompiledMechanicalModel {
        let joints=[try joint("s",parent:"root",child:"sphere",specification:.spherical),try joint("f",parent:"root",child:"free",specification:.sixDOF)]
        let q=[0.0,0,0,1,0,0,0],v=[0.0,0,0,0,0,0.3]
        return try compile(names:["root","sphere","free"],poses:[.identity,.identity,.identity],joints:joints,q:q,v:v,floating:true,
            jointCoordinates:["s":([1,0,0,0],[0,0,0.4]),"f":([0,0,0,1,0,0,0],[0,0,0,0,0,0.7])])
    }
}
