import SwiftMechanics
import Testing

enum IdentificationFixtures {
    enum Unexpected:Error { case success }
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func inertiaPolicy() throws -> InertiaValidationPolicy {
        try InertiaValidationPolicy(symmetry:NumericalTolerance(absolute:0,relative:0),physicalityRelative:0)
    }
    static func properties(_ mass:Double,_ com:Vector3 = .zero) throws -> MassProperties3D {
        try MassProperties3D(mass:mass,centerOfMass:com,inertiaAtCenter:Matrix3(mass,0,0,0,mass,0,0,0,mass),policy:inertiaPolicy())
    }
    static func source(rotation:UnitQuaternion = .identity,com:Vector3 = .zero,prismatic:Bool=true,key:String="carriage") throws -> PrismaticIdentificationSource {
        let rp=try properties(1),cp=try properties(2,com)
        let root=try BodyRecord3D(id:id(.body,"root"),frame:id(.frame,"root-frame"),mode:.dynamic,
            bodyToWorld:RigidTransform(rotation:rotation,translation:.zero),representations:BodyRepresentations(),
            inertia:InertialRepresentation3D(properties:rp,provenance:SourceProvenance(source:"identification",revision:7),quality:.exact))
        let child=try BodyRecord3D(id:id(.body,key),frame:id(.frame,"child-frame"),mode:.dynamic,bodyToWorld:.identity,representations:BodyRepresentations(),
            inertia:InertialRepresentation3D(properties:cp,provenance:SourceProvenance(source:"identification",revision:7),quality:.exact))
        let joint=try JointRecord(id:id(.joint,"rail"),parentBody:root.id,childBody:child.id,
            parentAnchor:JointAnchor(frame:id(.frame,"parent-anchor"),placement:.fixed(.identity)),
            childAnchor:JointAnchor(frame:id(.frame,"child-anchor"),placement:.fixed(.identity)),
            manifold:JointManifold(prismatic ? .prismatic(axis:.unitX) : .revolute(axis:.unitZ)))
        let tree=try KinematicTree(bodies:[KinematicBody(body:root),KinematicBody(body:child)],joints:[joint],root:root.id,
            rootBase:.fixed,worldFrame:id(.frame,"world"),revision:7,capacity:KinematicCapacity(maximumBodies:2,maximumVelocities:1,maximumJacobianScalars:12))
        return PrismaticIdentificationSource(tree:tree,referenceInertias:[try RigidBodyInertia(body:root.id,frame:root.frame,properties:rp),try RigidBodyInertia(body:child.id,frame:child.frame,properties:cp)],
            body:ModelReference(id:child.id,revision:7),massParameterID:11,dampingParameterID:12,dashpotRestCoordinate:0,maximumDisplacement:10,maximumRate:100)
    }
    static func joint() throws -> JointEvaluationPolicy {
        try JointEvaluationPolicy(quaternionTolerance:NumericalTolerance(absolute:1e-12,relative:1e-12),chartRankRelative:1e-10,characteristicLengthMeters:1)
    }
    static func admission() throws -> DynamicsAdmission {
        DynamicsAdmission(capacity:try DynamicsCapacity(maximumBodies:2,maximumVelocities:1,maximumBodyWrenches:0,maximumGeneralizedContributions:1),
            angularVelocityTolerance:try NumericalTolerance(absolute:1e-10,relative:1e-10),linearVelocityTolerance:try NumericalTolerance(absolute:1e-10,relative:1e-10))
    }
    static func linearTolerance() throws -> LinearTolerance<Double> { try LinearTolerance(absoluteResidual:1e-9,relativeResidual:1e-10,pivotThreshold:1e-12) }
    static func policy(observations:Int=20,metadata:Int=100000,models:Int=100,rank:Double=1e-10,candidates:Int=100,cancelled:Bool=false) throws -> IdentificationPolicy {
        let tolerance=try NumericalTolerance(absolute:1e-8,relative:1e-10)
        let capability=LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky)
        return try IdentificationPolicy(maximumObservations:observations,maximumMetadataBytes:metadata,maximumModelValidationAttempts:models,
            rankThreshold:rank,physicalAgreement:tolerance,normalizedAgreement:tolerance,informationAgreement:tolerance,joint:joint(),dynamics:admission(),
            derivative:DerivativePolicy(maximumBodies:2,maximumVelocities:1,maximumJacobianColumns:2,tolerance:tolerance,residualTolerance:tolerance,
                physicalNeighborhood:1e-3,inertiaValidation:inertiaPolicy()),inertiaValidation:inertiaPolicy(),
            optimization:OptimizationPolicy(maximumVariables:2,maximumRows:4,maximumNonzeros:8,maximumFactorEntries:16,maximumCandidateBases:candidates,
                rankThreshold:1e-10,certificateAbsolute:1e-9,certificateRelative:1e-10,
                luCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),curvatureCapability:capability,linearTolerance:linearTolerance()),
            informationCapability:capability,informationTolerance:linearTolerance(),isCancelled:{ cancelled })
    }
    static func work(operations:Int=10000000,storage:Int=1000000,iterations:Int=1000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations))
    }
    static func loadWork(maximum:Int=10000) throws -> LoadWork { LoadWork(budget:try LoadBudget(maximumWork:maximum,maximumScalars:0)) }
    static func calls(maximum:Int=10000) throws -> DerivativeSupplierWork { try DerivativeSupplierWork(maximumCalls:maximum) }
    static func synthetic(_ source:PrismaticIdentificationSource,third:Bool=false,correlated:Bool=false) throws -> [ForceObservation] {
        let velocities=third ? [1.0,2.0,-1.0] : [1.0,2.0]
        let efforts=correlated ? [4.5,9.0] : (third ? [2.5,-1.0,-0.5] : [2.5,-1.0])
        var observations:[ForceObservation]=[]
        for i in velocities.indices {
            let v=velocities[i],q=Double(i)*0.3
            let state=try KinematicState(revision:7,time:Double(i),q:[q],v:[v],acceleration:[0])
            let snapshot=try TreeKinematicsEvaluator().evaluate(source.tree,state:state,policy:joint())
            var loads=try loadWork(),work=try work()
            let law=try PolynomialSpringDamper(coordinateKind:.translation,restCoordinate:0,quadraticStiffness:0,linearDamping:0.5,maximumDisplacement:10,maximumRate:100)
            let damper=try ScalarLoadEvaluator().evaluate(law,coordinate:q,rate:v,work:&loads)
            let contribution=try GeneralizedForceContribution(values:[damper.dissipative],channel:.applied,potentialEnergy:0,dissipatedPower:damper.dissipatedPower)
            let input=try RigidDynamicsInput(snapshot:snapshot,velocity:[v],inertias:source.referenceInertias,gravity:nil,generalizedForces:[contribution])
            let system=try RigidEquationKernel().assemble(input,admission:admission(),loadWork:&loads,work:&work)
            let solved=try DenseRigidDynamics().forward(system,driveForce:[efforts[i]],policy:DynamicsSolvePolicy(
                capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),linearTolerance:linearTolerance(),coordinateScales:[1],energyScale:1,timeScale:1),work:&work)
            observations.append(ForceObservation(state:try KinematicState(revision:7,time:Double(i),q:[q],v:[v],acceleration:solved.acceleration),
                appliedForceNewtons:efforts[i],forceStandardDeviationNewtons:1))
        }
        return observations
    }
    static func problem(source:PrismaticIdentificationSource?=nil,observations:[ForceObservation]?=nil,third:Bool=false,
                        correlated:Bool=false,scales:[Double]=[1,1],lower:[Double]=[0.2,0],upper:[Double]=[4,4]) throws -> PhysicalIdentificationProblem {
        let source=try source ?? self.source()
        let metadata=try OptimizationMetadata(identity:"mass-damper",provenance:SourceProvenance(source:"identification",revision:7),variableIDs:[11,12],
            variableReferences:[SIReferenceQuantity(magnitude:scales[0],dimension:.mass),SIReferenceQuantity(magnitude:scales[1],dimension:PhysicalDimension(mass:1,time:-1))],
            objectiveReference:SIReferenceQuantity(magnitude:1,dimension:.dimensionless))
        return PhysicalIdentificationProblem(source:source,observations:try observations ?? synthetic(source,third:third,correlated:correlated),metadata:metadata,lowerBounds:lower,upperBounds:upper)
    }
    static func estimate(_ problem:PhysicalIdentificationProblem,policy:IdentificationPolicy?=nil,
                         service:any PhysicalParameterIdentifying = PhysicalMassDamperIdentifier()) throws -> PhysicalParameterEstimate {
        var workspace=IdentificationWorkspace(),loads=try loadWork(),calls=try calls(),work=try work()
        return try service.estimate(problem,policy:policy ?? self.policy(),workspace:&workspace,loadWork:&loads,supplierWork:&calls,work:&work)
    }
    static func failure(_ operation:() throws -> PhysicalParameterEstimate) throws -> ParameterIdentificationFailure {
        do { _=try operation();Issue.record("Identification must fail");throw Unexpected.success }
        catch let failure as ParameterIdentificationFailure { return failure }
    }
    static func close(_ a:Double,_ b:Double) -> Bool { abs(a-b) < 1e-7*max(1,abs(b)) }
}
