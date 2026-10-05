import SwiftMechanics

public enum URDFQualificationFixtures {
    public static func codec() -> BoundedURDFCodec<BoundedXMLCodec, ReferenceMechanicalCompiler<NoMechanicalExtensions>> {
        BoundedURDFCodec(markup: BoundedXMLCodec(), compiler: ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()))
    }
    public static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: key) }
    public static func options(floating: Bool = false, pose: RigidTransform = .identity,
                               losses: Bool = false, assets: Bool = false) throws -> URDFImportOptions {
        URDFImportOptions(identity: "urdf-fixture", provenance: try SourceProvenance(source: "authored-urdf", revision: 7),
            worldFrame: try id(.frame, "world"), rootName: "base", rootPlacement: floating ? .spatialFloating(pose) : .fixed(pose),
            units: .metresKilogramsSecondsRadians, lossMode: losses ? .preserveUnservedRepresentations : .prohibit,
            assetBase: assets ? "caller-catalog" : nil)
    }
    public static func work(links: Int = 16, joints: Int = 16, geometries: Int = 16, assets: Int = 16,
                            losses: Int = 32, identifier: Int = 256, reference: Int = 256,
                            operations: Int = 1_000_000, storage: Int = 1_000_000,
                            xmlInput: Int = 65_536, xmlOutput: Int = 65_536, xmlNodes: Int = 4096) throws -> URDFWork {
        URDFWork(policy: try URDFPolicy(maximumLinks: links, maximumJoints: joints, maximumGeometryRecords: geometries,
            maximumAssets: assets, maximumLosses: losses, maximumIdentifierBytes: identifier, maximumReferenceBytes: reference,
            maximumOperations: operations, maximumStorageBytes: storage),
            xmlPolicy: try XMLPolicy(maximumInputBytes: xmlInput, maximumOutputBytes: xmlOutput, maximumNodes: xmlNodes,
                maximumAttributes: 4096, maximumAttributesPerElement: 16, maximumDepth: 64, maximumDecodedBytes: 65_536,
                maximumStorageBytes: 524_288, maximumOperations: 1_000_000))
    }
    public static func compilation(records: Int = 128) throws -> CompilationPolicy {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        return try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 16, maximumVelocities: 16, maximumJacobianScalars: 1536),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-9, characteristicLengthMeters: 1),
            inertiaPolicy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0), translationTolerance: tolerance,
            rotationTolerance: tolerance, maximumRecords: records, maximumIdentifierBytes: 65_536, maximumSparsityEntries: 100_000,
            maximumDependencyEntries: 65_536, maximumExtensionRecords: 0, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 1024, arithmeticOperations: 100_000, iterations: 64), target: .nativeCPU)
    }
    public static func numerical(operations: Int = 1_000_000) throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 65_536, arithmeticOperations: operations, iterations: 1024))
    }
    public static func loads(operations: Int = 100_000) throws -> LoadWork {
        LoadWork(budget: try LoadBudget(maximumWork: operations, maximumScalars: 4096))
    }
    public static func dynamics() throws -> DynamicsAdmission {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        return DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 16, maximumVelocities: 16,
            maximumBodyWrenches: 16, maximumGeneralizedContributions: 16),
            angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance)
    }
    public static func unitInertia(mass: Int = 1) -> String {
        "<inertial><mass value='\(mass)'/><inertia ixx='1' ixy='0' ixz='0' iyy='1' iyz='0' izz='1'/></inertial>"
    }
    public static func minimal(link: String = "", robot: String = "") -> String {
        "<robot name='fixture'><link name='base'>" + link + "</link>" + robot + "</robot>"
    }
    public static let armInertia = "<inertial><origin xyz='1 0 0' rpy='0 0 1.5707963267948966'/><mass value='2'/>" +
        "<inertia ixx='2' ixy='0.25' ixz='0.3' iyy='3' iyz='0.4' izz='4'/></inertial>"
    public static func robot(rootInertia: Bool = true, axis: String = "0 0 2", movingInertia: Bool = true, damping: Bool = false) -> String {
        "<robot name='fixture' version='1.0'><link name='base'>" + (rootInertia ? unitInertia(mass: 3) : "") +
        "<collision><geometry><box size='2 2 2'/></geometry></collision></link><link name='arm'>" + (movingInertia ? armInertia : "") +
        "<collision><origin xyz='3 0 0'/><geometry><sphere radius='0.25'/></geometry></collision></link>" +
        "<link name='payload'>" + unitInertia() + "</link>" +
        "<joint name='spin' type='continuous'><origin xyz='1 0 0'/><parent link='base'/><child link='arm'/><axis xyz='" + axis + "'/>" +
        (damping ? "<dynamics damping='1'/>" : "") + "</joint>" +
        "<joint name='weld' type='fixed'><origin xyz='2 0 0'/><parent link='arm'/><child link='payload'/></joint></robot>"
    }
    public static let original = "<robot z='last' name='fixture'><!--remove--><link name='base'/><note b='2' a='日本&amp;x'/></robot>"
    public static let canonical = "<robot name=\"fixture\" z=\"last\"><link name=\"base\"></link><note a=\"日本&amp;x\" b=\"2\"></note></robot>"
    public static let mesh = "<visual><geometry><mesh filename='shapes/arm.stl' scale='1 2 3'/></geometry></visual>"
}
