import SwiftMechanics

public enum SDFQualificationFixtures {
    public static func codec() -> BoundedSDFCodec<ReferenceMechanicalCompiler<NoMechanicalExtensions>> {
        BoundedSDFCodec(compiler:ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()))
    }

    public static func source(revision: UInt64 = 7) throws -> SourceProvenance {
        try SourceProvenance(source:"authored-sdf-fixture",revision:revision)
    }

    public static func options(losses: Bool = false, assets: Bool = false) throws -> SDFImportOptions {
        try SDFImportOptions(identity:"sdf-fixture",source:source(),worldFrame:EntityID(kind:.frame,key:"world"),
            units:.metresKilogramsSecondsRadians,initialState:.restAtReferenceConfiguration,time:1.25,
            standaloneGravity:Vector3(0,0,-3),inertiaQuality:.exact,
            unservedRecords:losses ? .preserveOriginalWithExplicitLosses : .prohibit,
            assetRoot:assets ? SDFAssetRoot(key:"catalog-root",allowedSchemes:["model"],allowedPathPrefixes:["model://catalog/"]) : nil)
    }

    public static func policy(operations: Int = 20_000_000, storage: Int = 1_000_000,
                              iterations: Int = 4096, named: Int = 128, token: Int = 128,
                              xmlNodes: Int = 4096, xmlOutput: Int = 65_536) throws -> SDFPolicy {
        try SDFPolicy(xml:XMLPolicy(maximumInputBytes:65_536,maximumOutputBytes:xmlOutput,maximumNodes:xmlNodes,
            maximumAttributes:4096,maximumAttributesPerElement:16,maximumDepth:64,
            maximumDecodedBytes:65_536,maximumStorageBytes:524_288,maximumOperations:10_000_000),
            semanticBudget:NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations),
            maximumNamedRecords:named,maximumTokenBytes:token,maximumAssetBytes:256)
    }

    public static func compilation(records: Int = 128) throws -> CompilationPolicy {
        let tolerance = try NumericalTolerance(absolute:1e-10,relative:1e-10)
        return try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:16,maximumVelocities:64,maximumJacobianScalars:6144),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-9,characteristicLengthMeters:1),
            inertiaPolicy:InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0),
            translationTolerance:tolerance,rotationTolerance:tolerance,maximumRecords:records,
            maximumIdentifierBytes:65_536,maximumSparsityEntries:100_000,maximumDependencyEntries:65_536,
            maximumExtensionRecords:0,maximumDiagnostics:8,
            extensionBudget:NumericalBudget(scalarStorage:1024,arithmeticOperations:100_000,iterations:64),target:.nativeCPU)
    }

    public static func loadWork(operations: Int = 100_000, storage: Int = 4096,
                                cancelled: @escaping @Sendable () -> Bool = { false }) throws -> LoadWork {
        LoadWork(budget:try LoadBudget(maximumWork:operations,maximumScalars:storage,isCancelled:cancelled))
    }

    public static func minimal(model: String = "", link: String = "", version: String = "1.12") -> String {
        "<sdf version='"+version+"'><model name='m'><static>true</static><link name='base'>"+link+"</link>"+model+"</model></sdf>"
    }

    public static let unitInertia = "<inertial><mass>1</mass><inertia><ixx>1</ixx><ixy>0</ixy><ixz>0</ixz><iyy>1</iyy><iyz>0</iyz><izz>1</izz></inertia></inertial>"

    public static let nestedWorld = """
    <sdf version='1.12'><world name='fixture-world'><gravity>0 -10 0</gravity>
    <frame name='survey' attached_to='world'><pose>1 2 3 0 0 0</pose></frame>
    <model name='machine'><static>true</static><pose relative_to='survey'>9 -2 -3 0 0 1.5707963267948966</pose>
    <link name='base'><pose>0 2 0 0 0 0</pose><inertial>
    <pose rotation_format='quat_xyzw'>1 0 0 0 0 0.7071067811865475 0.7071067811865476</pose><mass>2</mass>
    <inertia><ixx>2</ixx><ixy>0</ixy><ixz>0</ixz><iyy>3</iyy><iyz>0</iyz><izz>4</izz></inertia>
    </inertial></link>
    <frame name='tool' attached_to='base'><pose relative_to='child::datum'>1 0 0 0 0 0</pose></frame>
    <joint name='weld' type='fixed'><parent>base</parent><child>child::tip</child></joint>
    <model name='child'><pose>2 0 0 0 0 0</pose><link name='tip'><pose>0 1 0 0 0 0</pose>
    <inertial><mass>3</mass><inertia><ixx>1</ixx><ixy>0</ixy><ixz>0</ixz><iyy>1</iyy><iyz>0</iyz><izz>1</izz></inertia></inertial>
    </link><frame name='datum' attached_to='tip'><pose>0 0 1 0 0 0</pose></frame></model>
    </model></world></sdf>
    """

    public static let hinge = "<sdf version='1.12'><model name='m' canonical_link='root'><link name='root'>"+unitInertia +
        "</link><link name='arm'><pose>1 0 0 0 0 0</pose>"+unitInertia +
        "</link><joint name='spin' type='continuous'><parent>root</parent><child>arm</child><axis><xyz>0 0 1</xyz></axis></joint>" +
        "<frame name='marker' attached_to='root'><pose>2 0 0 0 0 0</pose></frame>" +
        "<frame name='tip' attached_to='arm'><pose relative_to='marker'>0 0 0 0 0 0</pose></frame></model></sdf>"

    public static let metadata = "<sdf version='1.12'><!--meta🛠--><model name='m'><static>true</static><link name='base'>" +
        "<visual name='mesh'><geometry><mesh><uri>model://catalog/mesh.stl</uri></mesh></geometry><material><ambient>0.1 0.2 0.3 1</ambient></material></visual>" +
        "<sensor name='imu' type='imu'><update_rate>100</update_rate></sensor>" +
        "<plugin name='note' filename='model://catalog/plugin.so'>日本&amp;value</plugin></link></model></sdf>"

    public static let metadataExport = "<sdf version=\"1.12\"><!--meta🛠--><model name=\"m\"><static>true</static><link name=\"base\">" +
        "<visual name=\"mesh\"><geometry><mesh><uri>model://catalog/mesh.stl</uri></mesh></geometry><material><ambient>0.1 0.2 0.3 1</ambient></material></visual>" +
        "<sensor name=\"imu\" type=\"imu\"><update_rate>100</update_rate></sensor>" +
        "<plugin name=\"note\" filename=\"model://catalog/plugin.so\">日本&amp;value</plugin></link></model></sdf>"
}
