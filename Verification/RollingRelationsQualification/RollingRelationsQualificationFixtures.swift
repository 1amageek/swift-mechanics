import SwiftMechanics

public struct RollingRelationsQualificationFixtures: Sendable {
    public let model: CompiledMechanicalModel
    public let names: [String]
    public let root: EntityID
    public let rootFrame: EntityID
    public let wheel: EntityID
    public let wheelFrame: EntityID
    public let externalFrame: EntityID
    public let planeBody: EntityID
    public let planeFrame: EntityID

    public static func translated<T>(_ body: () throws -> T) throws(RollingRelationsQualificationError) -> T {
        do { return try body() }
        catch let error as RollingRelationsQualificationError { throw error }
        catch let error as RollingError { throw .rolling(error) }
        catch let error as CompilationFailure { throw .compilation(error) }
        catch let error as JointError { throw .joints(error) }
        catch let error as NumericalError { throw .numerical(error) }
        catch let error as CoreError { throw .geometry(error) }
        catch let error as ModelError { throw .model(error) }
        catch { throw .unexpectedSupplier }
    }
    public static func vector(_ x: Double, _ y: Double, _ z: Double) throws(RollingRelationsQualificationError) -> Vector3 {
        try translated { try Vector3(x,y,z) }
    }
    public static func id(_ kind: EntityKind, _ name: String) throws(RollingRelationsQualificationError) -> EntityID {
        try translated { try EntityID(kind: kind, key: "rolling-"+name) }
    }
    public init(camber: Bool = false, movingPlane: Bool = false, fixedWheel: Bool = false,
                identity: String = "rolling-independent") throws(RollingRelationsQualificationError) {
        let built = try Self.translated { () throws -> (CompiledMechanicalModel, [String]) in
            let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
            let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
            let provenance = try SourceProvenance(source: identity, revision: 1)
            let properties = try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .identity, policy: inertiaPolicy)
            let inertia = InertialRepresentation3D(properties: properties, provenance: provenance, quality: .exact)
            func body(_ name: String, pose: RigidTransform, fixed: Bool = false) throws -> MechanicalBody {
                .spatial(try BodyRecord3D(id: Self.id(.body,name), frame: Self.id(.frame,name+"-frame"),
                    mode: fixed ? .static : .dynamic, bodyToWorld: pose, representations: BodyRepresentations(), inertia: inertia))
            }
            var bodies = [try body("root",pose: .identity,fixed: true)]
            var joints: [MechanicalJoint] = [], names: [String] = []
            let rotation: UnitQuaternion
            if camber { rotation = try UnitQuaternion(w: 2,x: 1,y: 0,z: 0) } else { rotation = .identity }
            let placement = RigidTransform(rotation: rotation,translation: try Self.vector(0,0,camber ? 0.3 : 0.5))
            func append(_ name: String, parent: String, child: String, specification: JointSpecification,
                        anchor: RigidTransform = .identity, pose: RigidTransform = .identity) throws {
                bodies.append(try body(child,pose: pose))
                joints.append(MechanicalJoint(record: try JointRecord(id: Self.id(.joint,name),parentBody: Self.id(.body,parent),childBody: Self.id(.body,child),
                    parentAnchor: JointAnchor(frame: Self.id(.frame,name+"-parent"),placement: .fixed(anchor)),
                    childAnchor: JointAnchor(frame: Self.id(.frame,name+"-child"),placement: .fixed(.identity)),
                    manifold: JointManifold(specification)),authority: .dynamicState))
                names.append(name)
            }
            if !fixedWheel {
                try append("wheel-x",parent: "root",child: "wheel-x",specification: .prismatic(axis: .unitX))
                try append("wheel-y",parent: "wheel-x",child: "wheel-y",specification: .prismatic(axis: .unitY))
                try append("wheel-z",parent: "wheel-y",child: "wheel-z",specification: .prismatic(axis: .unitZ))
                try append("wheel-spin",parent: "wheel-z",child: "wheel",specification: .revolute(axis: .unitY),anchor: placement,pose: placement)
            }
            if movingPlane {
                try append("plane-x",parent: "root",child: "plane-x",specification: .prismatic(axis: .unitX))
                try append("plane-yaw",parent: "plane-x",child: "plane",specification: .revolute(axis: .unitZ))
            }
            let count = names.count, zero = [Double](repeating: 0,count: count)
            let descriptor = try MechanicalDescriptor(identity: identity,revision: 1,bodies: bodies,joints: joints,
                root: Self.id(.body,"root"),rootBase: .fixed,rootAuthority: .fixed,worldFrame: Self.id(.frame,"world"),
                initialState: KinematicState(revision: 1,time: 0,q: zero,v: zero,acceleration: zero),representationRequirements: [],features: [],extensions: [])
            let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 8,maximumVelocities: 6,maximumJacobianScalars: 288),
                jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance,chartRankRelative: 1e-10,characteristicLengthMeters: 1),
                inertiaPolicy: inertiaPolicy,translationTolerance: tolerance,rotationTolerance: tolerance,maximumRecords: 100,
                maximumIdentifierBytes: 4096,maximumSparsityEntries: 2048,maximumDependencyEntries: 4096,maximumExtensionRecords: 0,maximumDiagnostics: 10,
                extensionBudget: NumericalBudget(scalarStorage: 1024,arithmeticOperations: 100000,iterations: 1000),target: Self.target)
            let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
            return (try compiler.compile(descriptor,policy: policy),names)
        }
        model = built.0; names = built.1
        root = try Self.id(.body,"root"); rootFrame = try Self.id(.frame,"root-frame")
        wheel = try Self.id(.body,fixedWheel ? "root" : "wheel"); wheelFrame = try Self.id(.frame,fixedWheel ? "root-frame" : "wheel-frame")
        externalFrame = try Self.id(.frame,"external-plane")
        planeBody = try Self.id(.body,movingPlane ? "plane" : "root"); planeFrame = try Self.id(.frame,movingPlane ? "plane-frame" : "root-frame")
    }
    private static var target: CompilerTarget {
        #if arch(wasm32)
        #if hasFeature(Embedded)
        .embeddedWasiPreview1
        #else
        .wasiPreview1
        #endif
        #else
        .nativeCPU
        #endif
    }
    public func index(_ name: String) throws(RollingRelationsQualificationError) -> Int {
        let joint = try Self.id(.joint,name)
        guard let entry = model.tree.layout.joints.first(where: { $0.joint == joint }) else { throw .assertion("Original joint layout identity missing") }
        guard entry.positions.count == 1, entry.velocities.count == 1, entry.positions.start == entry.velocities.start else { throw .assertion("Selected Euclidean chart layout differs") }
        return entry.velocities.start
    }
    public func coordinates(_ authored: [Double]) throws(RollingRelationsQualificationError) -> [Double] {
        guard authored.count == names.count else { throw .assertion("Authored coordinate count mismatch") }
        var output = [Double](repeating: 0,count: names.count)
        for i in names.indices { output[try index(names[i])] = authored[i] }
        return output
    }
    public func state(q: [Double],v: [Double],a: [Double],time: Double = 0) throws(RollingRelationsQualificationError) -> CompiledKinematicState {
        try Self.translated { try model.makeState(KinematicState(revision: model.stamp.revision,time: time,
            q: coordinates(q),v: coordinates(v),acceleration: coordinates(a))) }
    }
    public func relation(prescribed: Bool = false, axis: Vector3 = .unitY, wheelFrame: EntityID? = nil,
                         binding: RollingPlaneBinding? = nil) throws(RollingRelationsQualificationError) -> RollingRelation {
        try Self.translated {
            let frame: EntityID
            if let wheelFrame { frame = wheelFrame } else { frame = self.wheelFrame }
            let center: Vector3
            if names.isEmpty { center = try Self.vector(0,0,0.5) } else { center = .zero }
            let wheel = try RollingWheel(body: self.wheel,frame: frame,center: center,axis: axis,radius: 0.5)
            let plane: RollingPlaneBinding
            if let binding { plane = binding }
            else if prescribed { plane = .prescribed(frame: externalFrame,sourceID: "plane-law",sourceRevision: 7,point: .zero,normal: .unitZ) }
            else { plane = .body(body: planeBody,frame: planeFrame,point: .zero,normal: .unitZ) }
            return try RollingRelation(model: model,sourceID: "rolling-source",sourceRevision: 31,referenceTime: 2.5,wheel: wheel,plane: plane,rowIDs: [11,12,13])
        }
    }
    public func sample(motion: FrameMotion = .stationary(pose: .identity),time: Double = 0,revision: UInt64 = 7,
                       stamp: ModelStamp? = nil,frame: EntityID? = nil) throws(RollingRelationsQualificationError) -> RollingPrescribedPlaneSample {
        let actualStamp: ModelStamp,actualFrame: EntityID
        if let stamp { actualStamp = stamp } else { actualStamp = model.stamp }
        if let frame { actualFrame = frame } else { actualFrame = externalFrame }
        return try Self.translated { try RollingPrescribedPlaneSample(sourceID: "plane-law",sourceRevision: revision,modelStamp: actualStamp,
            frame: actualFrame,worldFrame: model.tree.worldFrame,time: time,motion: motion) }
    }
    public func policy(independent: Bool = true,scales: [Double]? = nil,bodies: Int = 8,coordinates: Int = 6,metadata: Int = 4096,
                       contact: Double = 1e-9,chart: Double = 1e-8,cancelled: @escaping @Sendable () -> Bool = { false }) throws(RollingRelationsQualificationError) -> RollingEvaluationPolicy {
        let actual: [Double]
        if let scales { actual = scales } else { actual = [Double](repeating: 1,count: names.count) }
        return try Self.translated { try RollingEvaluationPolicy(maximumBodies: bodies,maximumCoordinates: coordinates,maximumMetadataBytes: metadata,
            contactTolerance: contact,minimumContactChartSine: chart,velocityScales: actual,rankRelativeTolerance: 1e-10,requireIndependentRows: independent,
            absoluteVelocityTolerance: 1e-10,absoluteAccelerationTolerance: 1e-10,relativeTolerance: 1e-10,isCancelled: cancelled) }
    }
    public static func work(storage: Int = 1000000,operations: Int = 10000000) throws(RollingRelationsQualificationError) -> NumericalWork {
        try translated { NumericalWork(budget: try NumericalBudget(scalarStorage: storage,arithmeticOperations: operations,iterations: 1000)) }
    }
    public func evaluate(_ state: CompiledKinematicState,relation: RollingRelation? = nil,sample: RollingPrescribedPlaneSample? = nil,
                         policy: RollingEvaluationPolicy? = nil) throws(RollingRelationsQualificationError) -> RollingEvaluation {
        let actualRelation: RollingRelation,actualPolicy: RollingEvaluationPolicy
        if let relation { actualRelation = relation } else { actualRelation = try self.relation() }
        if let policy { actualPolicy = policy } else { actualPolicy = try self.policy() }
        var work = try Self.work()
        let evaluator: any RollingConstraintEvaluating = RollingConstraintEvaluator()
        return try Self.translated { try evaluator.evaluate(actualRelation,state: state,prescribedPlane: sample,policy: actualPolicy,work: &work) }
    }
}
