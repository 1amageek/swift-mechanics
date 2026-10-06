import SwiftMechanics
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal enum IslandSleepImpactFixtures {
    static func law(_ restitution: Double, threshold: Double = 0) throws -> ContactLawPair {
        func material(_ key: String) throws -> ContactMaterial {
            try ContactMaterial(reference:ModelReference(id:IslandSleepMechanicalFixtures.id(.material,key),revision:1),youngModulus:1e6,poissonsRatio:0.2,
                linearStiffness:2000,normalDamping:0,huntCrossleyAlpha:0,friction:.none,
                resistance:ContactResistanceParameters(rollingCoefficient:0,spinningCoefficient:0,angularRegularization:0.1),cohesion:.none)
        }
        var work = try contact()
        return try SeriesContactPairing().combine(first:material("a"),second:material("striker"),
            selection:.linear(maximumPenetration:1,maximumNormalSpeed:100),lossPolicy:.separateImpact(restitution:restitution,thresholdSpeed:threshold),
            resistanceRadius:0.25,override:nil,work:&work)
    }
    static func policy(scales: [Double] = [1,1,1], entries: Int = 100) throws -> ConstrainedImpactPolicy {
        let tolerance = try LinearTolerance<Double>(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:1e-12)
        let lu = LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU)
        let nonlinear = try NonlinearPolicy<Double>(strategy:.newton,capability:lu,tolerance:tolerance,referenceScale:1,minimumDirectionNorm:0,
            derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-5,derivativeRelativeTolerance:1e-5,maximumFactorEntries:100,
            estimateCondition:false,budget:NumericalBudget(scalarStorage:10000,arithmeticOperations:100000,iterations:1000))
        return try ConstrainedImpactPolicy(impact:HybridPolicy(maximumContacts:2,maximumColliders:4,maximumBodies:4,maximumVelocities:3,
            maximumIdentifierBytes:256,lengthTolerance:1e-9,normalTolerance:1e-10,speedTolerance:1e-9,independenceTolerance:1e-10,
            impulseScales:[1,1,1],momentumAbsolute:1e-9,momentumRelative:1e-10,energyAbsolute:1e-9,energyRelative:1e-10),
            constraints:ConstraintSolvePolicy(evaluation:ConstraintEvaluationPolicy(maximumCoordinates:3,maximumRows:3,expectedLayoutRevision:1),
                diagonalMetric:[1,1,1],energyScale:1,rankPolicy:.allowRedundancy,rankRelativeTolerance:1e-10,originalResidualTolerance:1e-9,
                maximumCorrection:10,nonlinear:nonlinear,linearCapability:lu,linearTolerance:tolerance),
            dynamics:DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
                linearTolerance:tolerance,coordinateScales:scales,energyScale:1,timeScale:2),maximumFactorEntries:entries,minimumEffectiveInverseMass:1e-12)
    }
    static func contact() throws -> ContactWork { ContactWork(budget:try ContactBudget(operations:100000,scalarStorage:10000,records:10)) }
    static func input(_ owner:IslandCheckpointedMechanismSleep,physical:KinematicState,restitution:Double) throws -> HardImpactInput {
        let model=owner.model,compiled=try model.makeState(physical),snapshot=try model.evaluate(compiled)
        let offset=RigidTransform(rotation:.identity,translation:try Vector3(1,0,0))
        let firstPose=try snapshot.body(IslandSleepMechanicalFixtures.id(.body,"a")).motion.pose.composed(with:offset)
        let secondPose=try snapshot.body(IslandSleepMechanicalFixtures.id(.body,"striker")).motion.pose
        func proxy(_ key:String,body:String,pose:RigidTransform) throws -> CollisionProxy {
            try CollisionProxy(colliderID:IslandSleepMechanicalFixtures.id(.collider,key),bodyID:IslandSleepMechanicalFixtures.id(.body,body),frameID:IslandSleepMechanicalFixtures.id(.frame,"world"),geometryRevision:1,frameRevision:1,shape:.sphere(radius:0.25),margin:0,representations:IslandSleepMechanicalFixtures.representation(),expectedSourceRevision:1,resolution:.analytic,pose:pose,filter:ColliderFilter(enabled:true,layerBits:1,maskBits:1,isTrigger:false))
        }
        let first=try proxy("a",body:"a",pose:firstPose),second=try proxy("striker",body:"striker",pose:secondPose)
        var work=CollisionWork(budget:try CollisionBudget(scalarStorage:1000,operations:100000,iterations:1000,records:10))
        let witness=try AnalyticCollisionQueries().witness(first:first,second:second,policy:CollisionQueryPolicy(absoluteLengthTolerance:1e-10,relativeLengthTolerance:1e-10,referenceLength:1,maximumApproximationError:0),work:&work)
        let binding=ImpulseContactBinding(eventID:41,witness:witness,firstProxyIndex:0,secondProxyIndex:1,firstColliderToBody:offset,secondColliderToBody:.identity,law:try law(restitution))
        var inertias:[RigidBodyInertia]=[]
        for body in model.tree.bodies {
            guard let record=model.descriptor.bodies.first(where:{$0.id == body.id}),case .spatial(let spatial)=record,let inertia=spatial.inertia else { throw DynamicsError.invalidInput }
            inertias.append(try RigidBodyInertia(body:body.id,frame:body.frame,properties:inertia.properties))
        }
        return HardImpactInput(model:model,physical:compiled,inertias:inertias,collision:try CollisionSnapshot(proxies:[first,second],revision:1),expectedCollisionRevision:1,contacts:[binding])
    }
    static func impact(_ owner:IslandCheckpointedMechanismSleep,endpoint:IslandSleepTrajectoryEndpoint,restitution:Double) throws -> ConstrainedNormalImpulseResult {
        let input=try input(owner,physical:endpoint.physical,restitution:restitution),token=HybridCancellation()
        var work=try IslandSleepMechanicalFixtures.numerical(),loads=try IslandSleepMechanicalFixtures.load(token),contact=try self.contact()
        let prepared=try ReferenceConstrainedImpactPreparer().prepare(input:input,constraints:owner.program.constraints,policy:policy(),admission:IslandSleepMechanicalFixtures.admission(token),loadWork:&loads,work:&work,cancellation:token)
        return try ReferenceConstrainedNormalImpulseSolver().solve(prepared,work:&work,contactWork:&contact,cancellation:token)
    }
}
