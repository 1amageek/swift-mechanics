import SwiftMechanics
import Foundation

internal enum LoopFixtures {
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func work(storage:Int=4_000_000,operations:Int=50_000_000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:1000))
    }
    static func loads(cancelled:@escaping @Sendable ()->Bool={false}) throws -> LoadWork {
        LoadWork(budget:try LoadBudget(maximumWork:1000,maximumScalars:0,isCancelled:cancelled))
    }
    static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute:1e-9,relative:1e-10) }
    static func admission() throws -> DynamicsAdmission {
        DynamicsAdmission(capacity:try DynamicsCapacity(maximumBodies:8,maximumVelocities:12,maximumBodyWrenches:40,maximumGeneralizedContributions:8),
            angularVelocityTolerance:try tolerance(),linearVelocityTolerance:try tolerance())
    }
    static func evaluation() throws -> ConstraintEvaluationPolicy {
        try ConstraintEvaluationPolicy(maximumCoordinates:12,maximumRows:12,expectedLayoutRevision:1)
    }
    static func rowPolicy() throws -> GeometricPhysicalRowPolicy {
        try GeometricPhysicalRowPolicy(evaluation:evaluation(),maximumBodies:8,originalComparisonTolerance:1e-10,projectionTolerance:tolerance())
    }
    static func rankPolicy() throws -> ConstraintSolvePolicy {
        let linear=try LinearTolerance<Double>(absoluteResidual:1e-11,relativeResidual:1e-11,pivotThreshold:1e-13)
        let nonlinear=try NonlinearPolicy<Double>(strategy:.lineSearch(contraction:0.5,sufficientDecrease:1e-4,minimumFraction:1e-7),
            capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),tolerance:linear,referenceScale:1,
            minimumDirectionNorm:0,derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-4,derivativeRelativeTolerance:1e-4,
            maximumFactorEntries:5000,estimateCondition:false,budget:work().budget)
        return try ConstraintSolvePolicy(evaluation:evaluation(),diagonalMetric:[1,1],energyScale:7,rankPolicy:.allowRedundancy,
            rankRelativeTolerance:1e-10,originalResidualTolerance:1e-9,maximumCorrection:10,nonlinear:nonlinear,
            linearCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),linearTolerance:linear)
    }
    static func mechanismPolicy() throws -> MechanismSolvePolicy {
        try MechanismSolvePolicy(dynamics:DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:LinearTolerance(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:1e-13),
            coordinateScales:[2,3],energyScale:7,timeScale:5),constraints:rankPolicy(),maximumCoordinates:12,maximumRows:12,originalTolerance:1e-9,isCancelled:{false})
    }
    static func policy(rows:Int=12,bodyLoads:Int=40,cancelled:Bool=false) throws -> ClosedLoopReactionPolicy {
        let tree=try TreeReactionPolicy(maximumBodies:8,maximumJoints:8,maximumBodyLoads:bodyLoads,generalizedForceScales:[1,1],
            generalizedTolerance:tolerance(),forceTolerance:tolerance(),torqueTolerance:tolerance(),isCancelled:{cancelled})
        return try ClosedLoopReactionPolicy(maximumRows:rows,geometry:rowPolicy(),rank:rankPolicy(),tree:tree,admission:admission(),
            positionTolerance:1e-9,velocityTolerance:1e-9,accelerationTolerance:1e-9)
    }
    static func model(offset:Bool=false,planar:Bool=false) throws -> CompiledMechanicalModel {
        let t=try tolerance(),ip=try InertiaValidationPolicy(symmetry:t,physicalityRelative:0)
        let firstRotation=try UnitQuaternion(axis:.unitZ,angle:offset ? .pi/2 : 0)
        let poses=[RigidTransform.identity,RigidTransform(rotation:firstRotation,translation:.zero),RigidTransform(rotation:.identity,translation:try Vector3(2,0,0))]
        let names=["root","first","second"],masses=[1.0,2,3]
        var bodies:[MechanicalBody]=[]
        for i in names.indices {
            if planar {
                let properties=try MassProperties2D(mass:masses[i],centerX:0,centerY:0,polarInertiaAtCenter:1)
                bodies.append(.planar(try BodyRecord2D(id:id(.body,names[i]),frame:id(.frame,names[i]),mode:i == 0 ? .static : .dynamic,
                    bodyToWorld:PlanarPose(x:poses[i].translation.x,y:0,angle:i == 1 && offset ? .pi/2 : 0),representations:BodyRepresentations(),
                    inertia:InertialRepresentation2D(properties:properties,provenance:SourceProvenance(source:"loop-fixture",revision:1),quality:.exact))))
            } else {
                let properties=try MassProperties3D(mass:masses[i],centerOfMass:.zero,inertiaAtCenter:.identity,policy:ip)
                bodies.append(.spatial(try BodyRecord3D(id:id(.body,names[i]),frame:id(.frame,names[i]),mode:i == 0 ? .static : .dynamic,
                    bodyToWorld:poses[i],representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:properties,
                    provenance:SourceProvenance(source:"loop-fixture",revision:1),quality:.exact))))
            }
        }
        var joints:[MechanicalJoint]=[]
        for (i,key) in ["a","b"].enumerated() {
            let rotation=try UnitQuaternion(axis:.unitZ,angle:i == 0 && offset ? -.pi/2 : 0)
            let record=try JointRecord(id:id(.joint,key),parentBody:id(.body,"root"),childBody:id(.body,names[i+1]),
                parentAnchor:JointAnchor(frame:id(.frame,key+"-parent"),placement:.fixed(.identity)),
                childAnchor:JointAnchor(frame:id(.frame,key+"-child"),placement:.fixed(RigidTransform(rotation:rotation,translation:.zero))),
                manifold:JointManifold(.prismatic(axis:.unitX)))
            joints.append(MechanicalJoint(record:record,authority:.dynamicState))
        }
        let state=try KinematicState(revision:1,time:0,q:[0,2],v:[0,0],acceleration:[0,0])
        let descriptor=try MechanicalDescriptor(identity:"loop-fixture",revision:1,bodies:bodies,joints:joints,root:id(.body,"root"),
            rootBase:.fixed,rootAuthority:.fixed,worldFrame:id(.frame,"world"),initialState:state,representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:8,maximumVelocities:12,maximumJacobianScalars:3000),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:t,chartRankRelative:1e-10,characteristicLengthMeters:1),inertiaPolicy:ip,
            translationTolerance:t,rotationTolerance:t,maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:10000,
            maximumDependencyEntries:1000,maximumExtensionRecords:8,maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }
    static func geometry(_ model:CompiledMechanicalModel,scale:Double=4,duplicate:Bool=false,offset:Bool=false,
                         target:Double=2,support:Bool=false,rowID:UInt64=91) throws -> GeometricConstraintSystem {
        let first=try GeometricFrameEndpoint(body:id(.body,support ? "root" : "first"),frame:id(.frame,support ? "root" : "first"),point:offset ? .unitX : .zero)
        let second=try GeometricFrameEndpoint(body:id(.body,"second"),frame:id(.frame,"second"),point:offset ? .unitY : .zero)
        let analytic=try GeometricAnalyticTarget(value:Vector3(target,0,0))
        var relations=[try GeometricRelation(kind:.distance,rowIDs:[rowID],first:first,second:second,target:analytic,scale:scale)]
        if duplicate { relations.append(try GeometricRelation(kind:.distance,rowIDs:[92],first:first,second:second,target:analytic,scale:scale)) }
        let layout=try ConstraintCoordinateLayout(coordinateIDs:[1,2],dimensions:[.length,.length],scales:[2,3],timeScale:5,revision:1)
        var work=try work()
        return try GeometricConstraintSystem(model:model,layout:layout,relations:relations,minimumPosition:[-20,-20],maximumPosition:[20,20],minimumTime:-5,maximumTime:5,
            capacity:GeometricConstraintCapacity(maximumBodies:8,maximumPositions:12,maximumVelocities:12,maximumRows:12,maximumMetadataBytes:30000),work:&work)
    }
    static func rows(_ geometry:GeometricConstraintSystem,state:KinematicState) throws -> GeometricPhysicalRowWitness {
        var work=try work()
        let provider:any HolonomicGeometryProviding=GeometricRelationEvaluator()
        let sample=try provider.evaluate(geometry,state:state,policy:evaluation(),work:&work)
        return try provider.physicalRows(geometry,state:state,supplied:sample,policy:rowPolicy(),work:&work)
    }
    static func system(_ model:CompiledMechanicalModel,state:KinematicState,offset:Bool=false,force:Double=10,
                       generalized:Bool=false,gravity:Bool=false) throws -> RigidDynamicsSystem {
        let snapshot=try model.evaluate(model.makeState(state)),t=try tolerance()
        let masses=[1.0,2,3],names=["root","first","second"]
        let inertias=try names.indices.map { i in try RigidBodyInertia(body:id(.body,names[i]),frame:id(.frame,names[i]),
            properties:MassProperties3D(mass:masses[i],centerOfMass:.zero,inertiaAtCenter:.identity,policy:InertiaValidationPolicy(symmetry:t,physicalityRelative:0))) }
        let applied=try BodyWrenchContribution(body:id(.body,"first"),frame:snapshot.tree.worldFrame,referencePoint:offset ? .unitY : .zero,
            wrench:SpatialWrench(torque:.zero,force:Vector3(generalized ? 0 : force,0,offset ? 5 : 0)),channel:.applied)
        let input=try RigidDynamicsInput(snapshot:snapshot,velocity:state.v,inertias:inertias,
            gravity:gravity ? AffineGravity(frame:snapshot.tree.worldFrame,accelerationAtOrigin:Vector3(0,-10,0)) : nil,
            bodyWrenches:[applied],generalizedForces:generalized ? [GeneralizedForceContribution(values:[force,0],channel:.actuator)] : [])
        var work=try work(),load=try loads()
        return try RigidEquationKernel().assemble(input,admission:admission(),loadWork:&load,work:&work)
    }
    static func motion(_ system:RigidDynamicsSystem,rows:GeometricPhysicalRowWitness,drive:[Double]=[0,0],impulse:Bool=false) throws -> ConstrainedMotion {
        var work=try work(),dynamics=try self.work(),rank=try self.work(),linear=try self.work()
        let solver:any ConstrainedMechanismSolving=MassWeightedMechanismSolver()
        if impulse { return try solver.reconcileVelocity(system,sample:rows.original.velocity,policy:mechanismPolicy(),work:&work,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear) }
        return try solver.acceleration(system,sample:rows.original.velocity,drive:drive,policy:mechanismPolicy(),work:&work,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear)
    }
    static func input(scale:Double=4,duplicate:Bool=false,offset:Bool=false,gravity:Bool=false) throws -> ClosedLoopReactionInput {
        let model=try model(offset:offset),geometry=try geometry(model,scale:scale,duplicate:duplicate,offset:offset),state=model.descriptor.initialState
        let rows=try rows(geometry,state:state),system=try system(model,state:state,offset:offset,gravity:gravity)
        return ClosedLoopReactionInput(dynamics:system,geometry:geometry,state:state,physicalRows:rows,motion:try motion(system,rows:rows),originalDrive:[0,0],topology:.completeTreeAndDeclaredRows)
    }
    static func replacing(_ source:ClosedLoopReactionInput,dynamics:RigidDynamicsSystem?=nil,geometry:GeometricConstraintSystem?=nil,state:KinematicState?=nil,
                          rows:GeometricPhysicalRowWitness?=nil,motion:ConstrainedMotion?=nil,drive:[Double]?=nil,topology:ClosedLoopReactionTopology?=nil) -> ClosedLoopReactionInput {
        ClosedLoopReactionInput(dynamics:dynamics ?? source.dynamics,geometry:geometry ?? source.geometry,state:state ?? source.state,
            physicalRows:rows ?? source.physicalRows,motion:motion ?? source.motion,originalDrive:drive ?? source.originalDrive,topology:topology ?? source.topology)
    }
}
