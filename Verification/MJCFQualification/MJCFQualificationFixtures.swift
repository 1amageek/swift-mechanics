import SwiftMechanics

public enum MJCFQualificationFixtures {
    public static let source = "mjcf-authored-qualification"
    public static let revision: UInt64 = 19
    public static let slide = """
    <mujoco model="original-slide">
      <compiler angle="degree" inertiafromgeom="false"/>
      <option gravity="0 0 -9.81" timestep="0.002"/>
      <default>
        <joint damping="0" axis="0 0 1"/>
        <material rgba="0.1 0.2 0.3 0.4"/>
        <default class="move"><joint type="slide" axis="2 0 0" ref="2"/></default>
      </default>
      <asset><material name="paint"/></asset>
      <worldbody>
        <body name="slider" pos="1 2 3" quat="0.7071067811865476 0 0 0.7071067811865476" childclass="move">
          <joint name="j" pos="0.5 0 0"/>
          <inertial pos="0.1 0.2 0.3" quat="0.7071067811865476 0 0 0.7071067811865476" mass="2" diaginertia="2 3 4"/>
          <body name="tip" pos="1 0 0"><inertial pos="0 0 0" mass="1" diaginertia="1 1 1"/></body>
        </body>
      </worldbody>
      <tendon><fixed name="rope"><joint joint="j" coef="3"/></fixed></tendon>
      <actuator><motor name="drive" joint="j" gear="2"/></actuator>
      <equality><joint name="lock" joint1="j" polycoef="0.25 1 0 0 0"/></equality>
      <sensor>
        <jointpos name="jp" joint="j"/><jointvel name="jv" joint="j"/>
        <tendonpos name="tp" tendon="rope"/><tendonvel name="tv" tendon="rope"/>
        <actuatorpos name="ap" actuator="drive"/><actuatorvel name="av" actuator="drive"/>
      </sensor>
    </mujoco>
    """
    public static let hinge = """
    <mujoco model="original-hinge"><compiler angle="degree" inertiafromgeom="false"/>
      <worldbody><body name="rotor" pos="1 0 0">
        <joint name="h" type="hinge" axis="0 0 2" pos="0.5 0 0" ref="90"/>
        <inertial pos="0 0 0" mass="2" diaginertia="2 3 4"/>
      </body></worldbody><sensor><jointpos name="angle" joint="h"/><jointvel name="speed" joint="h"/></sensor>
    </mujoco>
    """
    public static func translated<T>(_ operation: () throws -> T) throws(MJCFQualificationError) -> T {
        do { return try operation() }
        catch let e as MJCFQualificationError { throw e }
        catch let e as MJCFError { throw .mjcf(e) }
        catch let e as CoreError { throw .core(e) }
        catch let e as ModelError { throw .model(e) }
        catch let e as JointError { throw .joint(e) }
        catch let e as CompilationFailure { throw .compilation(e) }
        catch let e as XMLFailure { throw .xml(e) }
        catch let e as ActuationError { throw .actuation(e) }
        catch let e as NumericalError { throw .numerical(e) }
        catch let e as ExchangeError { throw .exchange(e) }
        catch { throw .unexpectedSupplier }
    }
    public static func tolerance() throws(MJCFQualificationError) -> NumericalTolerance {
        try translated { try NumericalTolerance(absolute: 1e-10, relative: 1e-10) }
    }
    public static func compilerPolicy() throws(MJCFQualificationError) -> CompilationPolicy {
        try translated {
            try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 32, maximumVelocities: 32, maximumJacobianScalars: 8192),
                jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance(), chartRankRelative: 1e-9, characteristicLengthMeters: 1),
                inertiaPolicy: InertiaValidationPolicy(symmetry: tolerance(), physicalityRelative: 0), translationTolerance: tolerance(), rotationTolerance: tolerance(),
                maximumRecords: 1000, maximumIdentifierBytes: 100000, maximumSparsityEntries: 10000, maximumDependencyEntries: 10000,
                maximumExtensionRecords: 0, maximumDiagnostics: 8, extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10), target: target)
        }
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
    public static func context(equality: Bool = true) throws(MJCFQualificationError) -> MJCFImportContext {
        try translated {
            try MJCFImportContext(identity: "mjcf-qualified", source: SourceProvenance(source: source, revision: revision), compilationPolicy: compilerPolicy(),
                                  equalityDomain: equality ? [MJCFCoordinateDomain(jointName: "j", coordinateID: 11, minimum: -1, maximum: 1, scale: 0.2)] : [],
                                  minimumTime: 0, maximumTime: 10, timeScale: 2, equalityResidualScale: 0.5, equalityTolerance: tolerance())
        }
    }
    public static func policy(bodies: Int = 32, operations: Int = 10_000_000, storage: Int = 4_194_304,
                              losses: [MJCFLossCategory] = [.mujocoSolverExecution,.softEqualitySolver,.retainedRendering,.nativeSidecars],
                              cancelled: @escaping @Sendable () -> Bool = { false }) throws(MJCFQualificationError) -> MJCFPolicy {
        try translated { try MJCFPolicy(maximumBodies: bodies, maximumFeatures: 128, maximumDefaults: 16, maximumAttributes: 2048,
                                        maximumIdentifierBytes: 4096, maximumStorageBytes: storage, maximumOperations: operations, allowedLosses: losses, isCancelled: cancelled) }
    }
    public static func xmlWork() throws(MJCFQualificationError) -> XMLWork {
        try translated { XMLWork(policy: try XMLPolicy(maximumInputBytes: 65536, maximumOutputBytes: 65536, maximumNodes: 1024,
                maximumAttributes: 2048, maximumAttributesPerElement: 64, maximumDepth: 32, maximumDecodedBytes: 65536, maximumStorageBytes: 1_048_576, maximumOperations: 2_000_000)) }
    }
    public static func actuationWork() throws(MJCFQualificationError) -> ActuationWork {
        try translated { ActuationWork(budget: try ActuationBudget(maximumWork: 1_000_000, maximumScalars: 4096, maximumBytes: 1_048_576, maximumBindings: 128, maximumMetadataBytes: 4096)) }
    }
    public static func numericalWork() throws(MJCFQualificationError) -> NumericalWork {
        try translated { NumericalWork(budget: try NumericalBudget(scalarStorage: 65536, arithmeticOperations: 2_000_000, iterations: 1000)) }
    }
    public static func exchangeWork() throws(MJCFQualificationError) -> ExchangeWork {
        try translated {
            ExchangeWork(policy: try ExchangePolicy(maximumWireBytes: 65536, maximumRecords: 2048, maximumArrayElements: 8192,
                maximumStringBytes: 4096, maximumMetadataBytes: 65536, maximumAllocationBytes: 1_048_576, maximumOperations: 2_000_000,
                maximumUnitComponentCorrection: 1e-10, inertiaPolicy: InertiaValidationPolicy(symmetry: tolerance(), physicalityRelative: 0),
                extensionSchemas: [], featureNames: ["mechanics.compiler.tree"], assetFormats: []))
        }
    }
    public static func adapter() -> PinnedMJCFAdapter {
        PinnedMJCFAdapter(xml: BoundedXMLCodec(), compiler: ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()), native: SMNXNativeModelCodec(),
                          transmitter: ReferenceActuationTransmitter(mapper: LoadMapper()), constraints: QuadraticConstraintEvaluator())
    }
    public static func imported(_ text: String = slide, equality: Bool = true) throws(MJCFQualificationError) -> MJCFImportedModel {
        var work = MJCFWork(policy: try policy()), xml = try xmlWork(), actuation = try actuationWork(), numerical = try numericalWork()
        let codec: any MJCFSemanticCoding = adapter()
        return try translated { try codec.importModel(bytes: Array(text.utf8), context: context(equality: equality), work: &work,
                                                      xmlWork: &xml, actuationWork: &actuation, numericalWork: &numerical) }
    }
}
