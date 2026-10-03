import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints
import MechanicsCompiler
import MechanicsExchange

extension FoundationVerification {
    static func verifyExchange() throws {
        let extensionRecord = try MechanicalExtensionRecord(id: EntityID(kind: .load, key: "exchange-probe-load"),
            schema: "probe.stiffness", references: [EntityID(kind: .body, key: "compile-probe-child")],
            parameters: [ExtensionParameter(name: "stiffness", value: 2, dimension: PhysicalDimension(mass: 1, time: -2))])
        let fixture = try MechanicalProbeModel(extensions: [extensionRecord])
        let policy = try ExchangePolicy(maximumWireBytes: 10000, maximumRecords: 100, maximumArrayElements: 100,
            maximumStringBytes: 1000, maximumMetadataBytes: 10000, maximumAllocationBytes: 100000, maximumOperations: 100000,
            maximumUnitComponentCorrection: 1e-12, inertiaPolicy: fixture.inertiaPolicy,
            extensionSchemas: ["probe.stiffness"], featureNames: [], assetFormats: ["opaque.probe"])
        let asset = NativeInlineAsset(key: "unused", format: "opaque.probe", provenance: try SourceProvenance(source: "CAD源", revision: 1), bytes: [0,255,17])
        let document = NativeMechanicalDocument(descriptor: fixture.descriptor, assets: [asset])
        let codec: any NativeModelCoding = SMNXNativeModelCodec()
        var work = ExchangeWork(policy: policy)
        let bytes = try codec.encode(document: document, work: &work)
        let decoded = try codec.decode(bytes: bytes, work: &work)
        try require(decoded.document.descriptor.initialState == fixture.descriptor.initialState && decoded.document.assets[0].bytes == asset.bytes)
        try require(decoded.document.assets[0].provenance == asset.provenance && decoded.maximumComponentCorrection == 0)
        let loader: any NativeModelLoading = try ReferenceNativeModelLoader(compiler: ReferenceMechanicalCompiler(extensions: RuntimeCompilerValidator()), codec: codec)
        let loaded = try loader.load(bytes: bytes, compilationPolicy: fixture.policy, work: &work)
        try require(loaded.model.report.positionCount == 1 && loaded.model.report.velocityCount == 1 && loaded.model.extensionEvidence[0].work.operations == 12)
        let child = try EntityID(kind: .body, key: "compile-probe-child")
        let motion = try loaded.model.evaluate(loaded.model.makeState(loaded.model.descriptor.initialState)).body(child).motion
        try require(motion.velocity.angular == (try Vector3(0,0,2)))
        var bad = bytes; bad[0] = 0
        var rejected = false
        do throws(ExchangeError) { _ = try codec.decode(bytes: bad, work: &work) }
        catch { try require(error == .malformedHeader); rejected = true }
        try require(rejected)
        let zeroPolicy = try ExchangePolicy(maximumWireBytes: 0, maximumRecords: 100, maximumArrayElements: 100,
            maximumStringBytes: 1000, maximumMetadataBytes: 10000, maximumAllocationBytes: 100000, maximumOperations: 100000,
            maximumUnitComponentCorrection: 1e-12, inertiaPolicy: fixture.inertiaPolicy,
            extensionSchemas: ["probe.stiffness"], featureNames: [], assetFormats: [])
        var zeroWork = ExchangeWork(policy: zeroPolicy), bounded = false
        do throws(ExchangeError) { _ = try codec.decode(bytes: bytes, work: &zeroWork) }
        catch { try require(error == .resourceLimit(resource: .wireBytes, limit: 0)); bounded = true }
        try require(bounded && zeroWork.operations == 0)
    }
}
