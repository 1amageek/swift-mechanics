import SwiftMechanics

enum ContactRangeFixtures {
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:"raw-"+key) }
    static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute:1e-11,relative:1e-11) }
    static func representation() throws -> BodyRepresentations {
        try BodyRepresentations(collisionGeometry:GeometryRepresentation(kind:.collisionGeometry,assetKey:"declared-spheres",
            provenance:SourceProvenance(source:"raw-independent-proxy",revision:1),quality:.exact))
    }
    static func model(rotation:UnitQuaternion = .identity,mass:Double = 1) throws -> CompiledMechanicalModel {
        let props=try MassProperties3D(mass:mass,centerOfMass:.zero,inertiaAtCenter:.identity,
            policy:InertiaValidationPolicy(symmetry:tolerance(),physicalityRelative:0))
        let inertia=try InertialRepresentation3D(properties:props,provenance:SourceProvenance(source:"raw-inertia",revision:1),quality:.exact)
        let root=try BodyRecord3D(id:id(.body,"a"),frame:id(.frame,"a"),mode:.static,
            bodyToWorld:RigidTransform(rotation:rotation,translation:.zero),representations:representation(),inertia:inertia)
        let body=try BodyRecord3D(id:id(.body,"b"),frame:id(.frame,"b"),mode:.dynamic,
            bodyToWorld:RigidTransform(rotation:rotation,translation:rotation.rotating(Vector3(0.99,0,0))),representations:representation(),inertia:inertia)
        let manifold=try JointManifold(.custom(orderedAxes:[JointAxis(kind:.prismatic,direction:.unitX),
            JointAxis(kind:.prismatic,direction:.unitY),JointAxis(kind:.revolute,direction:.unitZ)]))
        let joint=try MechanicalJoint(record:JointRecord(id:id(.joint,"joint"),parentBody:root.id,childBody:body.id,
            parentAnchor:JointAnchor(frame:id(.frame,"parent"),placement:.fixed(.identity)),
            childAnchor:JointAnchor(frame:id(.frame,"child"),placement:.fixed(.identity)),manifold:manifold),authority:.dynamicState)
        let descriptor=try MechanicalDescriptor(identity:"raw-public-source",revision:1,bodies:[.spatial(body),.spatial(root)],joints:[joint],
            root:root.id,rootBase:.fixed,rootAuthority:.fixed,worldFrame:id(.frame,"world"),
            initialState:KinematicState(revision:1,time:0,q:[0.99,0,0],v:[0,0,0],acceleration:[0,0,0]),
            representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:2,maximumVelocities:3,maximumJacobianScalars:36),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance(),chartRankRelative:1e-10,characteristicLengthMeters:1),
            inertiaPolicy:InertiaValidationPolicy(symmetry:tolerance(),physicalityRelative:0),translationTolerance:tolerance(),rotationTolerance:tolerance(),
            maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:1000,maximumDependencyEntries:1000,
            maximumExtensionRecords:10,maximumDiagnostics:10,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }
    static func policy(colliders:Int=4,hits:Int=4,triggers:Int=8,metadata:Int=1000) throws -> ContactRangeObservationPolicy {
        try ContactRangeObservationPolicy(observation:ObservationPolicy(maximumBodies:4,maximumCoordinates:6,maximumReactionRows:0,maximumMetadataBytes:1000),
            query:CollisionQueryPolicy(absoluteLengthTolerance:1e-10,relativeLengthTolerance:1e-10,referenceLength:1,maximumApproximationError:0),
            contact:ContactAcceptancePolicy(absoluteEnergyTolerance:1e-9,absolutePowerTolerance:1e-9,relativeTolerance:1e-10,referenceEnergy:1,referencePower:1,coneTolerance:1e-10),
            maximumColliders:colliders,maximumHits:hits,maximumTactileBindings:1,maximumTriggerRecords:triggers,maximumMetadataBytes:metadata)
    }
    static func work(operations:Int=10_000_000,storage:Int=100000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:1000))
    }
    static func collision(operations:Int=10_000_000,storage:Int=100000,records:Int=100) throws -> CollisionWork {
        CollisionWork(budget:try CollisionBudget(scalarStorage:storage,operations:operations,iterations:1000,records:records))
    }
    static func contact(operations:Int=10_000_000,storage:Int=100000,records:Int=100) throws -> ContactWork {
        ContactWork(budget:try ContactBudget(operations:operations,scalarStorage:storage,records:records))
    }
    static func recipe(_ name:String,body:String,shape:CollisionShape = .sphere(radius:0.5),offset:Vector3 = .zero,
                       margin:Double=0,trigger:Bool=false) throws -> ObservationColliderBinding {
        try ObservationColliderBinding(colliderID:id(.collider,name),body:id(.body,body),geometryRevision:1,shape:shape,margin:margin,
            representations:representation(),expectedSourceRevision:1,resolution:.analytic,
            colliderToBody:RigidTransform(rotation:.identity,translation:offset),filter:ColliderFilter(enabled:true,layerBits:1,maskBits:1,isTrigger:trigger))
    }
    static func mount(_ body:String="a",offset:Vector3 = .zero,rotation:UnitQuaternion = .identity) throws -> ObservationMount {
        try ObservationMount(sensor:id(.sensor,"sensor-"+body),body:id(.body,body),sensorFrame:id(.frame,"sensor-"+body),
            sensorToBody:RigidTransform(rotation:rotation,translation:offset))
    }
    static func scene(model:CompiledMechanicalModel,recipes:[ObservationColliderBinding],time:Double=0,x:Double=0.99,
                      y:Double=0,angle:Double=0,velocity:[Double]=[0,0,0],policy:ContactRangeObservationPolicy?=nil) throws -> ContactRangeScene {
        let state=try model.makeState(KinematicState(revision:1,time:time,q:[x,y,angle],v:velocity,acceleration:[0,0,0]))
        var work=try self.work();let issuer:any ContactRangeScenePreparing=ReferenceContactRangeScenePreparer()
        return try issuer.prepare(model:model,state:state,colliders:recipes,revision:1,policy:policy ?? self.policy(),work:&work)
    }
    static func pair(friction:Bool=false) throws -> ContactLawPair {
        let law:ContactFrictionLaw = friction ? .elasticCoulomb(try ContactFrictionParameters(staticFirst:0.8,staticSecond:0.4,dynamicFirst:0.4,dynamicSecond:0.2,tangentialStiffness:2000,transitionSpeed:0.1)) : .none
        func material(_ name:String) throws -> ContactMaterial {
            try ContactMaterial(reference:ModelReference(id:id(.material,name),revision:1),youngModulus:1e6,poissonsRatio:0.2,
                linearStiffness:2000,normalDamping:0,huntCrossleyAlpha:0,friction:law,
                resistance:ContactResistanceParameters(rollingCoefficient:0,spinningCoefficient:0,angularRegularization:0.1),cohesion:.none)
        }
        var work=try contact()
        return try SeriesContactPairing().combine(first:material("ma"),second:material("mb"),
            selection:.linear(maximumPenetration:1,maximumNormalSpeed:100),lossPolicy:.compliantDampingOnly,resistanceRadius:0.5,override:nil,work:&work)
    }
    static func binding(scene:ContactRangeScene,pair:ContactLawPair,issued:Bool=false,tangent:Vector3 = .unitY) throws -> TactileContactBinding {
        let id=try ContactIdentity(key:"physical-contact",firstBody:ModelReference(id:self.id(.body,"a"),revision:1),
            secondBody:ModelReference(id:self.id(.body,"b"),revision:1),frame:ModelReference(id:self.id(.frame,"world"),revision:1),
            firstGeometryRevision:1,secondGeometryRevision:1,tangentLayoutRevision:1)
        var work=try contact();let service:any ContactLawEvaluating=CompliantContactEvaluator()
        let virgin=try service.initialHistory(identity:id,pair:pair,timeSeconds:issued ? 0 : scene.source.state.state.time,work:&work)
        let history:ContactHistory
        if issued {
            let rotation=try UnitQuaternion(axis:Vector3(1,1,1),angle:2*Double.pi/3)
            history=try service.evaluate(input:ContactInput(identity:id,basis:ContactBasis(frame:id.frame,contactToQuery:rotation),
                separation:-0.01,relativeVelocity:Vector3(0,0.001,0),relativeAngularVelocity:.zero,startTimeSeconds:0,timeStepSeconds:1),
                pair:pair,accepted:virgin,policy:policy().contact,work:&work).trialHistory
        } else { history=virgin }
        return try TactileContactBinding(firstCollider:self.id(.collider,"a"),secondCollider:self.id(.collider,"b"),pair:pair,accepted:history,
            tangentLayoutRevision:1,firstMaterialTangentInCollider:tangent)
    }
    static func close(_ a:Double,_ b:Double) -> Bool { abs(a-b) <= 1e-8+1e-10*abs(b) }
    static func close(_ a:Vector3,_ b:Vector3) throws -> Bool { try a.subtracting(b).magnitude() <= 1e-8 }
}
