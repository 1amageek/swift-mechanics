import SwiftMechanics

struct StructuralEquilibriumFixture {
    static func id(_ kind:EntityKind,_ key:String)throws->EntityID { try EntityID(kind:kind,key:key) }
    static func limits()throws->EquilibriumLimits { try EquilibriumLimits(coordinates:8,rows:8,cases:16,identifierBytes:1000,bodies:16) }
    static func work(storage:Int=200000,operations:Int=10000000,iterations:Int=1000)throws->NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations))
    }
    static func nonlinear(tolerance:Double=1e-10,iterations:Int=100)throws->NonlinearPolicy<Double> {
        try NonlinearPolicy(strategy:.lineSearch(contraction:0.5,sufficientDecrease:0.0001,minimumFraction:1e-10),capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),
            tolerance:LinearTolerance(absoluteResidual:tolerance,relativeResidual:0,pivotThreshold:1e-12),referenceScale:1,minimumDirectionNorm:1e-15,
            derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-4,derivativeRelativeTolerance:1e-4,maximumFactorEntries:10000,estimateCondition:false,
            budget:NumericalBudget(scalarStorage:100000,arithmeticOperations:10000000,iterations:iterations))
    }
    static func chart(_ n:Int=1,angle:Bool=false,revision:UInt64=1)throws->StaticCoordinateChart {
        try StaticCoordinateChart(stamp:ModelStamp(identity:"equilibrium-fixture",revision:revision),frame:id(.frame,"world"),coordinateIDs:(0..<n).map{UInt64($0+1)},
            joints:(0..<n).map{try id(.joint,"joint-\($0)")},dimensions:[PhysicalDimension](repeating:angle ? .angle : .length,count:n),scales:[Double](repeating:1,count:n),limits:limits())
    }
    static func springs(_ a:[Double]=[100],b:[Double]?=nil,c:[Double]?=nil,l:[Double]?=nil,revision:UInt64=1,energy:Double=1)throws->StaticForceModel {
        let n=a.count
        return try StaticForceModel(identity:"springs",chart:chart(n,revision:revision),law:.springs(linear:a,cubic:b ?? [Double](repeating:0,count:n),constant:c ?? [Double](repeating:0,count:n),loadDirection:l ?? [Double](repeating:1,count:n)),
            minimumPosition:[Double](repeating:-3,count:n),maximumPosition:[Double](repeating:3,count:n),parameterIdentity:"load-factor",minimumParameter:-100,maximumParameter:100,energyScale:energy,limits:limits())
    }
    static func branch(_ n:Int=1,minimum:Double = -3,maximum:Double=3,step:Double=10,identity:String="main")throws->EquilibriumBranch {
        try EquilibriumBranch(identity:identity,minimumPosition:[Double](repeating:minimum,count:n),maximumPosition:[Double](repeating:maximum,count:n),maximumNormalizedStep:step,limits:limits())
    }
    static func policy(_ n:Int=1,reaction:ReactionSelection = .independentRowRepresentative,tolerance:Double=1e-10,iterations:Int=100,cancelled:Bool=false)throws->EquilibriumPolicy {
        try EquilibriumPolicy(limits:limits(),nonlinear:nonlinear(tolerance:tolerance,iterations:iterations),physicalForceTolerances:[Double](repeating:1e-7,count:n),constraintTolerance:1e-8,reactionSelection:reaction,isCancelled:{cancelled})
    }
    static func solve(_ model:StaticForceModel,constraints:StaticConstraints?=nil,parameter:Double=0,seed:[Double]?=nil,branch:EquilibriumBranch?=nil,policy:EquilibriumPolicy?=nil)throws->EquilibriumSolution {
        var w=try work()
        return try ReferenceEquilibriumSolver().solve(model,constraints:constraints,initialPosition:seed ?? [Double](repeating:0,count:model.chart.count),parameter:parameter,time:0,
            branch:branch ?? self.branch(model.chart.count,minimum:model.minimumPosition[0],maximum:model.maximumPosition[0]),policy:policy ?? self.policy(model.chart.count),work:&w)
    }
    static func tolerance()throws->NumericalTolerance { try NumericalTolerance(absolute:1e-10,relative:1e-10) }
    static func compiled(_ n:Int=1,angle:Bool=false)throws->CompiledMechanicalModel {
        let provenance=try SourceProvenance(source:"equilibrium-fixture",revision:1)
        let ip=try InertiaValidationPolicy(symmetry:tolerance(),physicalityRelative:0)
        var bodies:[MechanicalBody]=[];var joints:[MechanicalJoint]=[]
        for index in -1..<n {
            let name=index<0 ? "root" : "child-\(index)"
            let properties=try MassProperties3D(mass:index<0 ? 1 : Double(index+2),centerOfMass:angle && index>=0 ? Vector3(0,-1,0) : .zero,inertiaAtCenter:.identity,policy:ip)
            bodies.append(.spatial(try BodyRecord3D(id:id(.body,name),frame:id(.frame,name+"-frame"),mode:index<0 ? .static : .dynamic,bodyToWorld:.identity,representations:BodyRepresentations(),
                inertia:InertialRepresentation3D(properties:properties,provenance:provenance,quality:.exact))))
            if index>=0 { let name="joint-\(index)"
                let record=try JointRecord(id:id(.joint,name),parentBody:id(.body,"root"),childBody:id(.body,"child-\(index)"),
                    parentAnchor:JointAnchor(frame:id(.frame,name+"-parent"),placement:.fixed(.identity)),childAnchor:JointAnchor(frame:id(.frame,name+"-child"),placement:.fixed(.identity)),
                    manifold:JointManifold(angle ? .revolute(axis:.unitZ) : .prismatic(axis:.unitX)))
                joints.append(MechanicalJoint(record:record,authority:.dynamicState))
            }
        }
        let zero=[Double](repeating:0,count:n)
        let descriptor=try MechanicalDescriptor(identity:"equilibrium-fixture",revision:1,bodies:bodies,joints:joints,root:id(.body,"root"),rootBase:.fixed,rootAuthority:.fixed,worldFrame:id(.frame,"world"),
            initialState:KinematicState(revision:1,time:0,q:zero,v:zero,acceleration:zero),representationRequirements:[],features:[],extensions:[])
        let cp=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:16,maximumVelocities:8,maximumJacobianScalars:10000),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance(),chartRankRelative:1e-10,characteristicLengthMeters:1),inertiaPolicy:ip,translationTolerance:tolerance(),rotationTolerance:tolerance(),
            maximumRecords:1000,maximumIdentifierBytes:10000,maximumSparsityEntries:10000,maximumDependencyEntries:10000,maximumExtensionRecords:0,maximumDiagnostics:10,
            extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:cp)
    }
    static func dynamics(_ compiled:CompiledMechanicalModel,q:[Double],velocity:[Double]?=nil)throws->RigidDynamicsSystem {
        let n=q.count;let zero=[Double](repeating:0,count:n)
        let state=try KinematicState(revision:compiled.stamp.revision,time:0,q:q,v:velocity ?? zero,acceleration:zero)
        let snapshot=try compiled.evaluate(compiled.makeState(state))
        var inertias:[RigidBodyInertia]=[]
        for body in snapshot.bodies {
            guard let descriptor = compiled.descriptor.bodies.first(where: { $0.id == body.body }),
                  case .spatial(let record) = descriptor, let inertia = record.inertia,
                  record.frame == body.bodyFrame else { throw DynamicsError.inertiaIdentityMismatch }
            inertias.append(try RigidBodyInertia(body: body.body, frame: body.bodyFrame, properties: inertia.properties))
        }
        let input=try RigidDynamicsInput(snapshot:snapshot,velocity:velocity ?? zero,inertias:inertias,gravity:nil)
        let admission=try DynamicsAdmission(capacity:DynamicsCapacity(maximumBodies:16,maximumVelocities:8,maximumBodyWrenches:0,maximumGeneralizedContributions:0),angularVelocityTolerance:tolerance(),linearVelocityTolerance:tolerance())
        var lw=LoadWork(budget:try LoadBudget(maximumWork:10000,maximumScalars:10000));var w=try work()
        return try RigidEquationKernel().assemble(input,admission:admission,loadWork:&lw,work:&w)
    }
    static func linearPolicy(_ n:Int=1,operations:Int=10000000)throws->EquilibriumLinearizationPolicy {
        try EquilibriumLinearizationPolicy(limits:limits(),capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            tolerance:LinearTolerance(absoluteResidual:1e-9,relativeResidual:1e-10,pivotThreshold:1e-12),displacementProbe:1e-5,parameterProbe:1e-5,
            derivativeAbsoluteTolerances:[Double](repeating:1e-5,count:n),derivativeRelativeTolerance:1e-6,constraintTolerance:1e-8,inertialAbsoluteTolerances:[Double](repeating:1e-9,count:n))
    }
}
