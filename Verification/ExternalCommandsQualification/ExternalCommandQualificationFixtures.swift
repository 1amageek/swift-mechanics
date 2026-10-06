import SwiftMechanics

public enum ExternalCommandQualificationFixtures {
    public static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: key) }
    public static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute: 1e-10, relative: 1e-11) }
    public static func actuationWork() throws -> ActuationWork {
        ActuationWork(budget: try ActuationBudget(maximumWork: 10000, maximumScalars: 100, maximumBytes: 4096, maximumBindings: 16, maximumMetadataBytes: 1000))
    }
    public static func numericalWork() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 100, arithmeticOperations: 10000, iterations: 0))
    }
    public static func work(packets: Int = 16, batch: Int = 16, metadata: Int = 10000, allocation: Int = 100000, operations: Int = 100000) throws -> ExternalCommandWork {
        ExternalCommandWork(policy: try ExternalCommandPolicy(maximumPackets: packets, maximumBatch: batch, maximumMetadataBytes: metadata, maximumAllocationBytes: allocation, maximumWork: operations))
    }
    public static func binding(translation: Bool = false) throws -> ActuatorBinding {
        try ActuatorBinding(actuator: id(.actuator, "drive"), joint: id(.joint, "joint"), frame: id(.frame, "world"), model: ModelStamp(identity: "actuation-model", revision: 1), lawRevision: 1, continuationKey: 99, positionIndex: 0, velocityIndex: 0, coordinate: translation ? .translation : .rotation, authority: .dynamicState, stateKind: .servo, stateDomain: ActuatorScalarDomain(primaryLower: -10, primaryUpper: 10, secondaryLower: -1000, secondaryUpper: 1000))
    }
    public static func checkpoint(interpolation: ExternalCommandInterpolation = .linear, delay: Double = 0.25, age: Double = 2, gap: Double = 1, translation: Bool = false, mode: DriveMode = .position) throws -> ExternalCommandCheckpoint {
        let model = try Self.model(translation: translation), binding = try Self.binding(translation: translation)
        let clock = try ControlClock(epochSeconds: 0, periodSeconds: 0.25, maximumTimeSeconds: 10, maximumTicks: 40)
        var actuator = try actuationWork(), work = try Self.work()
        let scheduler: any ExternalCommandScheduling = ReferenceExternalCommandScheduler()
        return try scheduler.bind(binding: binding, model: model, producer: "synthetic-clock", configurationRevision: 3, mode: mode, clock: clock, delaySeconds: delay, maximumAgeSeconds: age, maximumGapSeconds: gap, interpolation: interpolation, actuationWork: &actuator, work: &work)
    }
    public static func packet(_ checkpoint: ExternalCommandCheckpoint, sequence: UInt64, source: Double, arrival: Double, value: Double, unit: UnitDefinition? = nil, producer: String = "synthetic-clock") throws -> ExternalCommandPacket {
        let selectedUnit: UnitDefinition
        if let unit { selectedUnit = unit } else { selectedUnit = checkpoint.stream.siUnit }
        return ExternalCommandPacket(producer: producer, model: checkpoint.stream.binding.model, actuator: checkpoint.stream.binding.actuator, configurationRevision: 3, sequence: sequence, sourceTimeSeconds: source, arrivalTimeSeconds: arrival, unit: selectedUnit, value: value)
    }
    public static func model(revision:UInt64=1,authority:CoordinateAuthority = .dynamicState,translation:Bool=false) throws -> CompiledMechanicalModel {
        let tolerance=try self.tolerance(),inertiaPolicy=try InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0)
        let source=try SourceProvenance(source:"actuation-fixture",revision:1)
        let inertia=try InertialRepresentation3D(properties:MassProperties3D(mass:1,centerOfMass:.zero,inertiaAtCenter:.identity,policy:inertiaPolicy),provenance:source,quality:.exact)
        let root=try BodyRecord3D(id:id(.body,"root"),frame:id(.frame,"root-frame"),mode:.static,bodyToWorld:.identity,representations:BodyRepresentations(),inertia:nil)
        let child=try BodyRecord3D(id:id(.body,"child"),frame:id(.frame,"child-frame"),mode:authority == .prescribedMotion ? .prescribedKinematic : .dynamic,
            bodyToWorld:.identity,representations:BodyRepresentations(),inertia:inertia)
        let record=try JointRecord(id:id(.joint,"joint"),parentBody:root.id,childBody:child.id,parentAnchor:JointAnchor(frame:id(.frame,"parent-anchor"),placement:.fixed(.identity)),
            childAnchor:JointAnchor(frame:id(.frame,"child-anchor"),placement:.fixed(.identity)),manifold:JointManifold(translation ? .prismatic(axis:.unitX) : .revolute(axis:.unitZ)))
        let state=try KinematicState(revision:revision,time:0,q:[0],v:[0],acceleration:[0])
        let descriptor=try MechanicalDescriptor(identity:"actuation-model",revision:revision,bodies:[.spatial(root),.spatial(child)],joints:[MechanicalJoint(record:record,authority:authority)],
            root:root.id,rootBase:.fixed,rootAuthority:.fixed,worldFrame:id(.frame,"world"),initialState:state,representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:8,maximumVelocities:16,maximumJacobianScalars:384),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-9,characteristicLengthMeters:1),inertiaPolicy:inertiaPolicy,
            translationTolerance:tolerance,rotationTolerance:tolerance,maximumRecords:100,maximumIdentifierBytes:10000,maximumSparsityEntries:1000,maximumDependencyEntries:1000,
            maximumExtensionRecords:8,maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:0),target:target)
        return try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
    }

    public static var target: CompilerTarget {
        #if hasFeature(Embedded)
        .embeddedWasiPreview1
        #elseif arch(wasm32)
        .wasiPreview1
        #else
        .nativeCPU
        #endif
    }
}
