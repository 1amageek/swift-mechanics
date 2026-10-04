import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal enum HybridFixtures {
    typealias Contributors=HybridContributors<IntegrationContinuationProvider>
    typealias Handler=ReferenceRuntimeCheckpointHandler<Contributors,ReferenceModelRevisionUpdater>
    typealias Session=RuntimeSession<Handler>
    static func id(_ kind: EntityKind,_ key: String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func properties(_ mass: Double) throws -> MassProperties3D {
        try MassProperties3D(mass:mass,centerOfMass:.zero,inertiaAtCenter:.identity,
            policy:InertiaValidationPolicy(symmetry:NumericalTolerance(absolute:0,relative:0),physicalityRelative:0))
    }
    static func representation() throws -> BodyRepresentations {
        try BodyRepresentations(collisionGeometry:GeometryRepresentation(kind:.collisionGeometry,assetKey:"analytic",provenance:SourceProvenance(source:"hybrid-fixture",revision:1),quality:.exact))
    }
    static func model(two: Bool=false, q: Double=0.5, v: Double = -3, mass: Double=2) throws -> CompiledMechanicalModel {
        let n=two ? 2 : 1, tolerance=try NumericalTolerance(absolute:1e-12,relative:1e-12)
        let inertiaPolicy=try InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0)
        let provenance=try SourceProvenance(source:"hybrid-fixture",revision:1)
        func body(_ name: String,_ mode: BodyMotionMode,_ mass: Double,_ pose: RigidTransform) throws -> BodyRecord3D {
            try BodyRecord3D(id:id(.body,name),frame:id(.frame,name+"-frame"),mode:mode,bodyToWorld:pose,representations:representation(),
                inertia:InertialRepresentation3D(properties:properties(mass),provenance:provenance,quality:.exact))
        }
        let ground=try body("ground",.static,1,.identity)
        var bodies=[MechanicalBody.spatial(ground)], joints: [MechanicalJoint]=[]
        for i in 0..<n {
            let offset=try Vector3(Double(i)*2,0,0), local=RigidTransform(rotation:.identity,translation:offset)
            let child=try body("ball"+String(i),.dynamic,i == 0 ? mass : 3,RigidTransform(rotation:.identity,translation:try offset.adding(Vector3(0,0,q))))
            let joint=try JointRecord(id:id(.joint,"slide"+String(i)),parentBody:ground.id,childBody:child.id,
                parentAnchor:JointAnchor(frame:id(.frame,"parent"+String(i)),placement:.fixed(local)),
                childAnchor:JointAnchor(frame:id(.frame,"child"+String(i)),placement:.fixed(.identity)),manifold:JointManifold(.prismatic(axis:.unitZ)))
            bodies.append(.spatial(child)); joints.append(MechanicalJoint(record:joint,authority:.dynamicState))
        }
        let state=try KinematicState(revision:1,time:0,q:[Double](repeating:q,count:n),v:two ? [v,-2] : [v],acceleration:[Double](repeating:-10,count:n))
        let descriptor=try MechanicalDescriptor(identity:"hybrid-model",revision:1,bodies:bodies,joints:joints,root:ground.id,rootBase:.fixed,
            rootAuthority:.fixed,worldFrame:id(.frame,"world"),initialState:state,representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:4,maximumVelocities:4,maximumJacobianScalars:96),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-10,characteristicLengthMeters:1),inertiaPolicy:inertiaPolicy,
            translationTolerance:tolerance,rotationTolerance:tolerance,maximumRecords:100,maximumIdentifierBytes:10000,
            maximumSparsityEntries:1000,maximumDependencyEntries:1000,maximumExtensionRecords:10,maximumDiagnostics:10,
            extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }
    static func pair(e: Double=0.5, threshold: Double=0) throws -> ContactLawPair {
        func material(_ key: String) throws -> ContactMaterial {
            try ContactMaterial(reference:ModelReference(id:id(.material,key),revision:1),youngModulus:1e6,poissonsRatio:0.2,
                linearStiffness:2000,normalDamping:0,huntCrossleyAlpha:0,friction:.none,
                resistance:ContactResistanceParameters(rollingCoefficient:0,spinningCoefficient:0,angularRegularization:0.1),cohesion:.none)
        }
        var work=try contactWork()
        return try SeriesContactPairing().combine(first:material("a"),second:material("b"),selection:.linear(maximumPenetration:1,maximumNormalSpeed:100),
            lossPolicy:.separateImpact(restitution:e,thresholdSpeed:threshold),resistanceRadius:0.5,override:nil,work:&work)
    }
    static func proxy(_ key: String, body: String, shape: CollisionShape, pose: RigidTransform, revision: UInt64=1) throws -> CollisionProxy {
        try CollisionProxy(colliderID:id(.collider,key),bodyID:id(.body,body),frameID:id(.frame,"world"),geometryRevision:revision,frameRevision:1,
            shape:shape,margin:0,representations:representation(),expectedSourceRevision:1,resolution:.analytic,pose:pose,
            filter:ColliderFilter(enabled:true,layerBits:1,maskBits:1,isTrigger:false))
    }
    static func queryPolicy() throws -> CollisionQueryPolicy { try CollisionQueryPolicy(absoluteLengthTolerance:1e-10,relativeLengthTolerance:1e-10,referenceLength:1,maximumApproximationError:0) }
    static func impactPolicy(_ n: Int=1) throws -> HybridPolicy {
        try HybridPolicy(maximumContacts:4,maximumColliders:8,maximumBodies:4,maximumVelocities:4,maximumIdentifierBytes:256,
            lengthTolerance:1e-7,normalTolerance:1e-10,speedTolerance:1e-8,independenceTolerance:1e-10,
            impulseScales:[Double](repeating:1,count:n),momentumAbsolute:1e-9,momentumRelative:1e-10,energyAbsolute:1e-8,energyRelative:1e-10)
    }
    static func massPolicy(_ n: Int=1) throws -> DynamicsSolvePolicy {
        try DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:LinearTolerance(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:1e-12),coordinateScales:[Double](repeating:1,count:n),energyScale:1,timeScale:1)
    }
    static func admission(cancellation: HybridCancellation) throws -> DynamicsAdmission {
        try DynamicsAdmission(capacity:DynamicsCapacity(maximumBodies:4,maximumVelocities:4,maximumBodyWrenches:0,maximumGeneralizedContributions:0),
            angularVelocityTolerance:NumericalTolerance(absolute:1e-10,relative:1e-10),linearVelocityTolerance:NumericalTolerance(absolute:1e-10,relative:1e-10),isCancelled:{ cancellation.isCancelled })
    }
    static func numerical(operations: Int=10000000, storage: Int=100000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:10000))
    }
    static func collisionWork() throws -> CollisionWork { CollisionWork(budget:try CollisionBudget(scalarStorage:1000,operations:10000000,iterations:1000,records:10)) }
    static func contactWork() throws -> ContactWork { ContactWork(budget:try ContactBudget(operations:100000,scalarStorage:1000,records:10)) }
    static func work(cancellation: HybridCancellation, operations: Int=10000000) throws -> HybridEvolutionWork {
        try HybridEvolutionWork(numerical:numerical(operations:operations),collision:collisionWork(),contact:contactWork(),
            loads:LoadWork(budget:LoadBudget(maximumWork:10000,maximumScalars:1000,isCancelled:{ cancellation.isCancelled })))
    }
    static func input(two: Bool=false, duplicate: Bool=false, e: Double=0.5) throws -> HardImpactInput {
        let model=try model(two:two), physical=try model.makeState(model.descriptor.initialState)
        let plane=try proxy("floor",body:"ground",shape:.halfSpace,pose:.identity)
        var proxies=[plane], contacts: [ImpulseContactBinding]=[], inertias: [RigidBodyInertia]=[], work=try collisionWork()
        for i in 0..<(two ? 2 : 1) {
            let sphere=try proxy("sphere"+String(i),body:"ball"+String(i),shape:.sphere(radius:0.5),pose:model.initialSnapshot.bodies[i+1].motion.pose)
            proxies.append(sphere)
            let witness=try AnalyticCollisionQueries().witness(first:sphere,second:plane,policy:queryPolicy(),work:&work)
            contacts.append(ImpulseContactBinding(eventID:UInt64(two ? 20-i*10 : 10),witness:witness,firstProxyIndex:i+1,secondProxyIndex:0,
                firstColliderToBody:.identity,secondColliderToBody:.identity,law:try pair(e:e)))
        }
        if duplicate { let first=contacts[0]; contacts.append(ImpulseContactBinding(eventID:11,witness:first.witness,firstProxyIndex:first.firstProxyIndex,secondProxyIndex:0,
            firstColliderToBody:.identity,secondColliderToBody:.identity,law:first.law)) }
        for body in try model.evaluate(physical).bodies {
            if let descriptor=model.descriptor.bodies.first(where: { $0.id == body.body }), case .spatial(let record)=descriptor, let inertia=record.inertia {
                inertias.append(try RigidBodyInertia(body:record.id,frame:record.frame,properties:inertia.properties))
            }
        }
        return try HardImpactInput(model:model,physical:physical,inertias:inertias,collision:CollisionSnapshot(proxies:proxies,revision:1),expectedCollisionRevision:1,contacts:contacts)
    }
    static func solve(_ input: HardImpactInput, cancellation: HybridCancellation=HybridCancellation(), operations: Int=10000000) throws -> NormalImpulseResult {
        let n=input.physical.state.v.count; var work=try work(cancellation:cancellation,operations:operations)
        let adapter:any ImpactPortAdapting=RigidHardImpactAdapter(), solver:any NormalImpulseSolving=IndependentNormalImpulseSolver()
        let prepared=try adapter.prepare(input,policy:impactPolicy(n),admission:admission(cancellation:cancellation),loadWork:&work.loads,work:&work.numerical,cancellation:cancellation)
        return try solver.solve(prepared,policy:impactPolicy(n),massPolicy:massPolicy(n),work:&work.numerical,contactWork:&work.contact,cancellation:cancellation)
    }
    static func evolutionPolicy(events: Int=10, queries: Int=500, roots: Int=64) throws -> HybridEvolutionPolicy {
        try HybridEvolutionPolicy(maximumEvents:events,maximumQueries:queries,maximumRootIterations:roots,maximumCatalogEvents:4,maximumContinuationBytes:4096,timeTolerance:1e-9,minimumEventSpacing:1e-6)
    }
    static func setup(q: Double=1.5, v: Double=0, e: Double=0.5, events: Int=10, queries: Int=500, operations: Int=10000000,
                      stepWork: Int=10000) throws -> (Session,ReferenceHybridEvolution,HybridContinuationProvider,IntegrationContinuationProvider,HybridCancellation,HybridEvolutionWork) {
        let model=try model(q:q,v:v), token=HybridCancellation(), equation=try PrismaticBallisticEquation(model:model,accelerationMetersPerSecondSquared:-10,cancellation:token,maximumIdentityBytes:256)
        let integrationPolicy=try ExplicitIntegrationPolicy(method:.classicalRK4,initialStep:0.1,minimumStep:1e-10,maximumStep:0.1,safety:0.8,minimumFactor:0.1,maximumFactor:2,
            scales:[ODEErrorScale(dimension:.length,absoluteSI:1e-10,relative:0),ODEErrorScale(dimension:PhysicalDimension(length:1,time:-1),absoluteSI:1e-10,relative:0)],maximumContinuationBytes:2048,
            budget:IntegrationBudget(maximumCoordinates:2,maximumAttempts:100,maximumAcceptedSteps:100,maximumOuterArithmetic:100000,supplier:NumericalBudget(scalarStorage:100,arithmeticOperations:10000,iterations:1000)))
        let smooth=try IntegrationContinuationProvider(descriptor:equation.descriptor,policy:integrationPolicy)
        let policy=try evolutionPolicy(events:events,queries:queries), impact=try impactPolicy()
        let sphere=try proxy("sphere",body:"ball0",shape:.sphere(radius:0.5),pose:model.initialSnapshot.bodies[1].motion.pose)
        let plane=try proxy("floor",body:"ground",shape:.halfSpace,pose:.identity)
        let environment=try SpherePlaneBallisticEnvironment(model:model,equation:equation,sphere:sphere,plane:plane,sphereToBody:.identity,planeToBody:.identity,
            law:pair(e:e),eventID:10,geometryRevision:1,queryPolicy:queryPolicy(),evolutionPolicy:policy,impactPolicy:impact)
        let history=try HybridContinuationProvider(catalog:environment.catalog,policy:policy,impactPolicy:impact,model:model)
        let contributors=try Contributors(base:smooth,events:history), handler=Handler(contributors:contributors,revisions:ReferenceModelRevisionUpdater())
        let configuration=try RuntimeConfiguration(continuation:RuntimeContinuationIdentity(build:"hybrid-test-v1",backend:"reference",precision:"float64"),requiredContributors:contributors.schemas,
            capacity:RuntimeCapacity(maximumPhysicalScalars:3,maximumContributors:2,maximumContributorBytes:8192,maximumMetadataBytes:4096,maximumCheckpointBytes:16384,
                maximumValidationWork:8192,maximumValidationScratchBytes:4096,maximumObservationLeases:1,maximumBatchStates:1,maximumTransactions:10000,
                maximumStepWorkUnits:stepWork,maximumWorkBetweenSafePoints:2),determinism:.sameBuildReplay,workload:"sphere-plane-ballistic")
        let state=model.descriptor.initialState
        let session=try Session(model:model,configuration:configuration,initialState:state,contributors:[smooth.initialRecord(physical:state,equations:equation),history.initialRecord(physical:state)],seed:42,checkpoints:handler)
        let trajectory=try IsolatedIntegrationTrajectory(model:model,equations:equation,continuation:smooth,configuration:configuration,checkpoints:handler,integrator:ReferenceExplicitIntegrator())
        let evolution=try ReferenceHybridEvolution(trajectory:trajectory,environment:environment,continuation:history,admission:admission(cancellation:token),massPolicy:massPolicy())
        return (session,evolution,history,smooth,token,try work(cancellation:token,operations:operations))
    }
}
