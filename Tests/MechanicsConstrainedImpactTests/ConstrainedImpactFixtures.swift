import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal enum ConstrainedImpactFixtures {
    static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind:kind,key:"constrained-"+key) }
    static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute:1e-12,relative:1e-12) }
    static func properties(_ mass: Double) throws -> MassProperties3D {
        try MassProperties3D(mass:mass,centerOfMass:.zero,inertiaAtCenter:Matrix3(2,0,0,0,2,0,0,0,2),
            policy:InertiaValidationPolicy(symmetry:tolerance(),physicalityRelative:0))
    }
    static func representation() throws -> BodyRepresentations {
        try BodyRepresentations(collisionGeometry:GeometryRepresentation(kind:.collisionGeometry,assetKey:"constrained-analytic",
            provenance:SourceProvenance(source:"constrained-impact-fixture",revision:1),quality:.exact))
    }
    static func model(speed: Double = -1, time: Double = 0.25) throws -> CompiledMechanicalModel {
        let provenance = try SourceProvenance(source:"constrained-impact-fixture",revision:1)
        func body(_ key: String, mode: BodyMotionMode, origin: Vector3) throws -> BodyRecord3D {
            try BodyRecord3D(id:id(.body,key),frame:id(.frame,key+"-body"),mode:mode,
                bodyToWorld:RigidTransform(rotation:.identity,translation:origin),representations:representation(),
                inertia:InertialRepresentation3D(properties:properties(mode == .static ? 1 : 2),provenance:provenance,quality:.exact))
        }
        let root = try body("root",mode:.static,origin:.zero)
        let a = try body("a",mode:.dynamic,origin:.zero)
        let b = try body("b",mode:.dynamic,origin:Vector3(3,0,0))
        let striker = try body("striker",mode:.dynamic,origin:Vector3(1,0.5,0))
        func joint(_ key: String, child: BodyRecord3D, origin: Vector3, kind: JointKind) throws -> MechanicalJoint {
            let manifold: JointManifold
            if kind == .revolute { manifold = try JointManifold(.revolute(axis:.unitZ)) }
            else { manifold = try JointManifold(.prismatic(axis:.unitY)) }
            return try MechanicalJoint(record:JointRecord(id:id(.joint,key),parentBody:root.id,childBody:child.id,
                parentAnchor:JointAnchor(frame:id(.frame,key+"-parent"),placement:.fixed(RigidTransform(rotation:.identity,translation:origin))),
                childAnchor:JointAnchor(frame:id(.frame,key+"-child"),placement:.fixed(.identity)),manifold:manifold),authority:.dynamicState)
        }
        let descriptor = try MechanicalDescriptor(identity:"constrained-impact-model",revision:1,
            // Descriptor order differs from actual tree order to exercise original inertia binding.
            bodies:[.spatial(striker),.spatial(b),.spatial(root),.spatial(a)],
            joints:[joint("a",child:a,origin:.zero,kind:.revolute),joint("b",child:b,origin:Vector3(3,0,0),kind:.revolute),
                    joint("striker",child:striker,origin:Vector3(1,0,0),kind:.prismatic)],root:root.id,rootBase:.fixed,
            rootAuthority:.fixed,worldFrame:id(.frame,"world"),
            initialState:KinematicState(revision:1,time:time,q:[0,0,0.5],v:[0,0,speed],acceleration:[0,0,0]),
            representationRequirements:[],features:[],extensions:[])
        let policy = try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:4,maximumVelocities:3,maximumJacobianScalars:96),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance(),chartRankRelative:1e-10,characteristicLengthMeters:1),
            inertiaPolicy:InertiaValidationPolicy(symmetry:tolerance(),physicalityRelative:0),translationTolerance:tolerance(),rotationTolerance:tolerance(),
            maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:1000,maximumDependencyEntries:1000,
            maximumExtensionRecords:10,maximumDiagnostics:10,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }
    static func law(_ restitution: Double, threshold: Double = 0) throws -> ContactLawPair {
        func material(_ key: String) throws -> ContactMaterial {
            try ContactMaterial(reference:ModelReference(id:id(.material,key),revision:1),youngModulus:1e6,poissonsRatio:0.2,
                linearStiffness:2000,normalDamping:0,huntCrossleyAlpha:0,friction:.none,
                resistance:ContactResistanceParameters(rollingCoefficient:0,spinningCoefficient:0,angularRegularization:0.1),cohesion:.none)
        }
        var work = try contact()
        return try SeriesContactPairing().combine(first:material("a"),second:material("striker"),
            selection:.linear(maximumPenetration:1,maximumNormalSpeed:100),lossPolicy:.separateImpact(restitution:restitution,thresholdSpeed:threshold),
            resistanceRadius:0.25,override:nil,work:&work)
    }
    static func input(restitution: Double = 1, speed: Double = -1, threshold: Double = 0) throws -> HardImpactInput {
        let model = try model(speed:speed), physical = try model.makeState(model.descriptor.initialState)
        let snapshot = try model.evaluate(physical)
        let offset = RigidTransform(rotation:.identity,translation:try Vector3(1,0,0))
        let aPose = try snapshot.body(id(.body,"a")).motion.pose.composed(with:offset)
        let bPose = try snapshot.body(id(.body,"striker")).motion.pose
        func proxy(_ key: String, body: String, pose: RigidTransform) throws -> CollisionProxy {
            try CollisionProxy(colliderID:id(.collider,key),bodyID:id(.body,body),frameID:id(.frame,"world"),geometryRevision:1,frameRevision:1,
                shape:.sphere(radius:0.25),margin:0,representations:representation(),expectedSourceRevision:1,resolution:.analytic,
                pose:pose,filter:ColliderFilter(enabled:true,layerBits:1,maskBits:1,isTrigger:false))
        }
        let first = try proxy("a",body:"a",pose:aPose), second = try proxy("striker",body:"striker",pose:bPose)
        var collision = CollisionWork(budget:try CollisionBudget(scalarStorage:1000,operations:100000,iterations:1000,records:10))
        let witness = try AnalyticCollisionQueries().witness(first:first,second:second,
            policy:CollisionQueryPolicy(absoluteLengthTolerance:1e-10,relativeLengthTolerance:1e-10,referenceLength:1,maximumApproximationError:0),work:&collision)
        let contact = ImpulseContactBinding(eventID:41,witness:witness,firstProxyIndex:0,secondProxyIndex:1,
            firstColliderToBody:offset,secondColliderToBody:.identity,law:try law(restitution,threshold:threshold))
        var inertias: [RigidBodyInertia] = []
        for body in model.tree.bodies {
            guard let record = model.descriptor.bodies.first(where:{ $0.id == body.id }), case .spatial(let spatial) = record,
                  let inertia = spatial.inertia else { throw DynamicsError.invalidInput }
            inertias.append(try RigidBodyInertia(body:body.id,frame:body.frame,properties:inertia.properties))
        }
        return try HardImpactInput(model:model,physical:physical,inertias:inertias,collision:CollisionSnapshot(proxies:[first,second],revision:1),
            expectedCollisionRevision:1,contacts:[contact])
    }
    static func constraints(_ model: CompiledMechanicalModel, scales: [Double] = [1,1,1], phaseScale: Double = 1) throws -> QuadraticConstraintSystem {
        let layout = try ConstraintCoordinateLayout(coordinateIDs:[10,20,30],dimensions:[.angle,.angle,.length],scales:scales,timeScale:2,revision:1)
        var ports: [TransmissionPortBinding] = []
        for i in 0..<2 {
            let key = i == 0 ? "a" : "b", jointID = try id(.joint,key)
            guard let record = model.descriptor.joints.first(where:{ $0.record.id == jointID }) else { throw JointError.disconnectedTree }
            ports.append(try TransmissionPortBinding(coordinateIndex:i,coordinateID:layout.coordinateIDs[i],body:id(.body,key),joint:record.record.id,
                frame:id(.frame,"world"),manifold:record.record.manifold,jointToReference:RigidTransform(rotation:.identity,translation:try Vector3(Double(i)*3,0,0)),
                layoutRevision:1,modelRevision:1))
        }
        var work = try numerical()
        return try AffineTransmissionCompiler().compile(id:9,layout:layout,ports:ports,
            relations:[TransmissionRelation(id:7,kind:.externalGear(first:0,second:1,firstTeeth:1,secondTeeth:1,phase:0,phaseScale:phaseScale))],
            minimumPosition:[-10,-10,-10],maximumPosition:[10,10,10],minimumTime:0,maximumTime:10,
            policy:TransmissionPolicy(maximumCoordinates:3,maximumPorts:2,maximumRelations:3,expectedLayoutRevision:1,expectedModelRevision:1,
                geometryTolerance:1e-10,originalTolerance:1e-9,powerScale:1,powerTolerance:1e-9),work:&work).equations
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
    static func admission(_ token: HybridCancellation) throws -> DynamicsAdmission {
        try DynamicsAdmission(capacity:DynamicsCapacity(maximumBodies:4,maximumVelocities:3,maximumBodyWrenches:0,maximumGeneralizedContributions:0),
            angularVelocityTolerance:tolerance(),linearVelocityTolerance:tolerance(),isCancelled:{ token.isCancelled })
    }
    static func numerical(operations: Int = 10000000, storage: Int = 100000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:10000))
    }
    static func load(_ token: HybridCancellation) throws -> LoadWork {
        LoadWork(budget:try LoadBudget(maximumWork:100000,maximumScalars:10000,isCancelled:{ token.isCancelled }))
    }
    static func contact() throws -> ContactWork { ContactWork(budget:try ContactBudget(operations:100000,scalarStorage:10000,records:10)) }
    static func prepared(_ input: HardImpactInput, constraints: QuadraticConstraintSystem? = nil,
                         policy: ConstrainedImpactPolicy? = nil) throws -> PreparedConstrainedImpact {
        let token = HybridCancellation(); var work = try numerical(), loads = try load(token)
        return try ReferenceConstrainedImpactPreparer().prepare(input:input,constraints:constraints ?? self.constraints(input.model),
            policy:policy ?? self.policy(),admission:admission(token),loadWork:&loads,work:&work,cancellation:token)
    }
}
