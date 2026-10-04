import SwiftMechanics
import Foundation

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal enum GeometricEvolutionFixtures {
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func work(storage:Int = 4_000_000,operations:Int = 50_000_000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:10000))
    }
    static func evaluation(cancelled:@escaping @Sendable ()->Bool = {false}) throws -> ConstraintEvaluationPolicy {
        try ConstraintEvaluationPolicy(maximumCoordinates:24,maximumRows:30,expectedLayoutRevision:1,isCancelled:cancelled)
    }
    static func compile(names:[String],poses:[RigidTransform],joints:[JointRecord],q:[Double],v:[Double],floating:Bool=false,jointCoordinates:[String:([Double],[Double])]?=nil) throws -> CompiledMechanicalModel {
        let tolerance=try NumericalTolerance(absolute:1e-9,relative:1e-9),ip=try InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0)
        let properties=try MassProperties3D(mass:1,centerOfMass:.zero,inertiaAtCenter:Matrix3(1,0,0,0,1,0,0,0,1),policy:ip)
        var bodies:[MechanicalBody]=[]
        for i in names.indices {
            bodies.append(.spatial(try BodyRecord3D(id:id(.body,names[i]),frame:id(.frame,names[i]),mode:i == 0 && !floating ? .static : .dynamic,
                bodyToWorld:poses[i],representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:properties,
                provenance:SourceProvenance(source:"geometry-test",revision:1),quality:.exact))))
        }
        let orderedJoints=joints.sorted { $0.id.key < $1.id.key }
        let tree=try KinematicTree(bodies:bodies.map { try $0.kinematicBody() },joints:orderedJoints,root:id(.body,names[0]),
            rootBase:floating ? .spatialFloating : .fixed,worldFrame:id(.frame,"world"),revision:1,
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
        let state=try KinematicState(revision:1,time:0,q:position,v:velocity,acceleration:[Double](repeating:0,count:velocity.count))
        let descriptor=try MechanicalDescriptor(identity:"geometric-fixture",revision:1,bodies:bodies,joints:orderedJoints.map { MechanicalJoint(record:$0,authority:.dynamicState) },
            root:id(.body,names[0]),rootBase:floating ? .spatialFloating : .fixed,rootAuthority:floating ? .dynamicState : .fixed,
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
    static func layout(_ model:CompiledMechanicalModel,scales:[Double]? = nil) throws -> ConstraintCoordinateLayout {
        var dimensions:[PhysicalDimension]=[]
        if model.tree.rootBase == .spatialFloating { dimensions += [.length,.length,.length,.angle,.angle,.angle] }
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
            jointCoordinates:["s":([1,0,0,0],[0,0,0.4]),"f":([0,0,0,1,0,0,0],[0,0,0,0,0,0.4])])
    }
    static func system(_ model:CompiledMechanicalModel,relations:[GeometricRelation]) throws -> GeometricConstraintSystem {
        var work=try work()
        return try GeometricConstraintSystem(model:model,layout:layout(model),relations:relations,
            minimumPosition:[Double](repeating:-100,count:model.tree.layout.positionCount),maximumPosition:[Double](repeating:100,count:model.tree.layout.positionCount),minimumTime:0,maximumTime:40,
            capacity:GeometricConstraintCapacity(maximumBodies:12,maximumPositions:24,maximumVelocities:24,maximumRows:30,maximumMetadataBytes:30000),work:&work)
    }
    static func equation(_ system:GeometricConstraintSystem,drive:[Double]? = nil,chartLimit:Double = 0.01,
                         evaluator:any HolonomicGeometryProviding = GeometricRelationEvaluator(),kernel:any RigidEquationComputing = RigidEquationKernel(),solver:any ConstrainedMechanismSolving = MassWeightedMechanismSolver()) throws -> GeometricMechanismEquation {
        let projection=try policy(system.layout.scales.count),base=try NonlinearMechanismFixtures.policy(scales:system.layout.scales,gramLU:true)
        let policy=try MechanismSolvePolicy(dynamics:DynamicsSolvePolicy(capability:base.dynamics.capability,linearTolerance:base.dynamics.linearTolerance,
            coordinateScales:system.layout.scales,energyScale:7,timeScale:system.layout.timeScale),constraints:projection.constraints,maximumCoordinates:24,maximumRows:30,originalTolerance:1e-8)
        let admission=DynamicsAdmission(capacity:try DynamicsCapacity(maximumBodies:12,maximumVelocities:24,maximumBodyWrenches:8,maximumGeneralizedContributions:8),
            angularVelocityTolerance:try NumericalTolerance(absolute:1e-9,relative:1e-9),linearVelocityTolerance:try NumericalTolerance(absolute:1e-9,relative:1e-9))
        return try GeometricMechanismEquation(identity:"geometric-force-evolution",geometry:system,drive:drive ?? [Double](repeating:0,count:system.layout.scales.count),
            policy:policy,projection:projection,maximumStageChartCorrection:chartLimit,publicationBudget:work().budget,admission:admission,maximumIdentityBytes:50000,kernel:kernel,evaluator:evaluator,solver:solver)
    }
    static func fourbarSystem(_ fixture:GeometricEvolutionFourBar) throws -> GeometricConstraintSystem {
        let first=try GeometricFrameEndpoint(body:fixture.coupler,frame:id(.frame,fixture.coupler.key+"-frame"),point:Vector3(2,0,0))
        let second=try GeometricFrameEndpoint(body:fixture.rocker,frame:id(.frame,fixture.rocker.key+"-frame"),point:Vector3(2,0,0))
        return try system(fixture.model,relations:[GeometricRelation(kind:.coincidence,rowIDs:[501,502,503],first:first,second:second,target:GeometricAnalyticTarget(),scale:2)])
    }
    static func mixedSystem(_ model:CompiledMechanicalModel) throws -> GeometricConstraintSystem {
        let first=try GeometricFrameEndpoint(body:id(.body,"sphere"),frame:id(.frame,"sphere"),axis:.unitX)
        let second=try GeometricFrameEndpoint(body:id(.body,"free"),frame:id(.frame,"free"),axis:.unitX)
        return try system(model,relations:[GeometricRelation(kind:.coincidence,rowIDs:[1,2,3],first:first,second:second,target:GeometricAnalyticTarget(),scale:1),
            GeometricRelation(kind:.alignedAxes,rowIDs:[4,5],first:first,second:second,target:GeometricAnalyticTarget(),scale:1)])
    }
}
