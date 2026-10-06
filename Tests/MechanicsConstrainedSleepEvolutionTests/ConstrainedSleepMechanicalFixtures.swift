import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal enum ConstrainedSleepMechanicalFixtures {
    static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind:kind,key:"constrained-event-"+key) }
    static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute:1e-12,relative:1e-12) }
    static func properties(_ mass: Double, inertia:Double = 2) throws -> MassProperties3D {
        try MassProperties3D(mass:mass,centerOfMass:.zero,inertiaAtCenter:Matrix3(inertia,0,0,0,inertia,0,0,0,inertia),
            policy:InertiaValidationPolicy(symmetry:tolerance(),physicalityRelative:0))
    }
    static func representation() throws -> BodyRepresentations {
        try BodyRepresentations(collisionGeometry:GeometryRepresentation(kind:.collisionGeometry,assetKey:"constrained-event-analytic",
            provenance:SourceProvenance(source:"constrained-event-impact-fixture",revision:1),quality:.exact))
    }
    static func model(speed: Double = -1, time: Double = 0.25, mass:Double = 2, inertia:Double = 2, anchor:Double = 3,descendant:Bool = false) throws -> CompiledMechanicalModel {
        let provenance = try SourceProvenance(source:"constrained-event-impact-fixture",revision:1)
        func body(_ key: String, mode: BodyMotionMode, origin: Vector3) throws -> BodyRecord3D {
            try BodyRecord3D(id:id(.body,key),frame:id(.frame,key+"-body"),mode:mode,
                bodyToWorld:RigidTransform(rotation:.identity,translation:origin),representations:representation(),
                inertia:InertialRepresentation3D(properties:properties(mode == .static ? 1 : mass,inertia:inertia),provenance:provenance,quality:.exact))
        }
        let root = try body("root",mode:.static,origin:.zero)
        let a = try body("a",mode:.dynamic,origin:.zero)
        let b = try body("b",mode:.dynamic,origin:Vector3(anchor,0,0))
        let striker = try body("striker",mode:.dynamic,origin:Vector3(1,0.5,0))
        func joint(_ key: String, child: BodyRecord3D, origin: Vector3, kind: JointKind) throws -> MechanicalJoint {
            let manifold: JointManifold
            if kind == .revolute { manifold = try JointManifold(.revolute(axis:.unitZ)) }
            else { manifold = try JointManifold(.prismatic(axis:.unitY)) }
            return try MechanicalJoint(record:JointRecord(id:id(.joint,key),parentBody:descendant && key == "b" ? a.id : root.id,childBody:child.id,
                parentAnchor:JointAnchor(frame:id(.frame,key+"-parent"),placement:.fixed(RigidTransform(rotation:.identity,translation:origin))),
                childAnchor:JointAnchor(frame:id(.frame,key+"-child"),placement:.fixed(.identity)),manifold:manifold),authority:.dynamicState)
        }
        let bodies:[MechanicalBody]=[.spatial(striker),.spatial(b),.spatial(root),.spatial(a)]
        let joints=[try joint("a",child:a,origin:.zero,kind:.revolute),try joint("b",child:b,origin:Vector3(anchor,0,0),kind:.revolute),
                    try joint("striker",child:striker,origin:Vector3(1,0,0),kind:.prismatic)]
        let tree=try KinematicTree(bodies:try bodies.sorted {$0.id.key < $1.id.key}.map {try $0.kinematicBody()},
            joints:joints.sorted {$0.record.id.key < $1.record.id.key}.map {$0.record},root:root.id,rootBase:.fixed,worldFrame:id(.frame,"world"),revision:1,
            capacity:KinematicCapacity(maximumBodies:4,maximumVelocities:3,maximumJacobianScalars:96))
        var q=[Double](repeating:0,count:3),v=q
        let sliderID=try id(.joint,"striker")
        guard let slider=tree.layout.joints.first(where:{$0.joint == sliderID}) else { throw JointError.invalidPolicy }
        q[slider.velocities.start]=0.5;v[slider.velocities.start]=speed
        let descriptor = try MechanicalDescriptor(identity:"constrained-event-impact-model",revision:1,
            bodies:bodies,joints:joints,root:root.id,rootBase:.fixed,rootAuthority:.fixed,worldFrame:id(.frame,"world"),
            initialState:KinematicState(revision:1,time:time,q:q,v:v,acceleration:[0,0,0]),
            representationRequirements:[],features:[],extensions:[])
        let policy = try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:4,maximumVelocities:3,maximumJacobianScalars:96),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance(),chartRankRelative:1e-10,characteristicLengthMeters:1),
            inertiaPolicy:InertiaValidationPolicy(symmetry:tolerance(),physicalityRelative:0),translationTolerance:tolerance(),rotationTolerance:tolerance(),
            maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:1000,maximumDependencyEntries:1000,
            maximumExtensionRecords:10,maximumDiagnostics:10,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }
    static func constraints(_ model: CompiledMechanicalModel, scales: [Double] = [1,1,1], phaseScale: Double = 1) throws -> QuadraticConstraintSystem {
        var ids=[UInt64](repeating:0,count:3),dimensions=[PhysicalDimension](repeating:.angle,count:3)
        for range in model.tree.layout.joints {
            if range.joint == (try id(.joint,"a")) { ids[range.velocities.start]=10 }
            else if range.joint == (try id(.joint,"b")) { ids[range.velocities.start]=20 }
            else { ids[range.velocities.start]=30;dimensions[range.velocities.start] = .length }
        }
        let layout = try ConstraintCoordinateLayout(coordinateIDs:ids,dimensions:dimensions,scales:scales,timeScale:2,revision:1)
        var ports: [TransmissionPortBinding] = []
        for i in 0..<2 {
            let key = i == 0 ? "a" : "b", jointID = try id(.joint,key)
            guard let record = model.descriptor.joints.first(where:{ $0.record.id == jointID }) else { throw JointError.disconnectedTree }
            guard let range=model.tree.layout.joints.first(where:{$0.joint == jointID}) else { throw JointError.invalidPolicy }
            ports.append(try TransmissionPortBinding(coordinateIndex:range.velocities.start,coordinateID:layout.coordinateIDs[range.velocities.start],body:id(.body,key),joint:record.record.id,
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
    static func policy(scales:[Double] = [1,1,1],energy:Double = 1,islands:Int = 3,calls:Int = 3,signature:Int = 65536,
                       token:HybridCancellation = HybridCancellation()) throws -> StationaryIslandPolicy {
        let tolerance = try LinearTolerance<Double>(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:1e-12)
        let lu = LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU)
        let nonlinear = try NonlinearPolicy<Double>(strategy:.newton,capability:lu,tolerance:tolerance,referenceScale:1,minimumDirectionNorm:0,
            derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-5,derivativeRelativeTolerance:1e-5,maximumFactorEntries:100,
            estimateCondition:false,budget:NumericalBudget(scalarStorage:10000,arithmeticOperations:100000,iterations:1000))
        let constraints=try ConstraintSolvePolicy(evaluation:ConstraintEvaluationPolicy(maximumCoordinates:3,maximumRows:3,expectedLayoutRevision:1),
            diagonalMetric:[1,1,1],energyScale:energy,rankPolicy:.allowRedundancy,rankRelativeTolerance:1e-10,originalResidualTolerance:1e-9,
            maximumCorrection:10,nonlinear:nonlinear,linearCapability:lu,linearTolerance:tolerance)
        let dynamics=try DynamicsSolvePolicy(capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:tolerance,coordinateScales:scales,energyScale:energy,timeScale:2)
        return try StationaryIslandPolicy(maximumIslands:islands,maximumSignatureBytes:signature,maximumIdentifierBytes:10000,maximumCompilationCalls:calls,
            mechanics:MechanismSolvePolicy(dynamics:dynamics,constraints:constraints,maximumCoordinates:3,maximumRows:3,originalTolerance:1e-9),admission:admission(token))
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
    static func work(operations:Int = 10000000,storage:Int = 100000,token:HybridCancellation = HybridCancellation()) throws -> StationaryIslandWork {
        StationaryIslandWork(numerical:try numerical(operations:operations,storage:storage),loads:try load(token))
    }
    static func program(drive:[Double] = [0,0,0],model:CompiledMechanicalModel? = nil,policy:StationaryIslandPolicy? = nil) throws -> StationaryIslandProgram {
        let source=try model ?? self.model();var work=try self.work()
        return try ReferenceStationaryIslandPreparer().prepare(source:source,constraints:constraints(source),drive:drive,policy:policy ?? self.policy(),work:&work)
    }
    static func thresholds() throws -> MechanismSleepPolicy {
        try MechanismSleepPolicy(maximumCoordinates:3,kineticEnergyThreshold:0.01,normalizedVelocityThreshold:0.01)
    }
}
