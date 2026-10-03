import Testing
@testable import MechanicsExchange
import MechanicsCore
import MechanicsModel
import MechanicsCompiler
import MechanicsJoints

@Suite struct AdmissionTests {
    private func raw(_ document:NativeMechanicalDocument) throws -> [UInt8] {
        var measure=try NativeWireWriter(work:ExchangeWork(policy:ExchangeFixtures.policy()),measuring:true)
        try measure.document(document)
        var writer=try NativeWireWriter(work:measure.work,measuring:false,reservation:measure.size)
        try writer.document(document);return writer.bytes
    }
    private func reject(_ document:NativeMechanicalDocument,_ error:ExchangeError) throws {
        #expect(throws:error) { try ExchangeFixtures.encode(document) }
        let bytes=try raw(document)
        #expect(throws:error) { try ExchangeFixtures.decode(bytes) }
    }
    @Test func assetAssociationProvenanceAndWhitelist() throws {
        let source=try ExchangeFixtures.document()
        try reject(ExchangeFixtures.replace(source,assets:[]),.missingAsset)
        var assets=source.assets;assets.append(assets[0])
        try reject(ExchangeFixtures.replace(source,assets:assets),.duplicateAsset)
        assets=source.assets;assets[0]=NativeInlineAsset(key:"shape",format:"opaque.native.v1",provenance:try ExchangeFixtures.provenance(revision:8),bytes:[1])
        try reject(ExchangeFixtures.replace(source,assets:assets),.staleAsset)
        assets=source.assets;assets[0]=NativeInlineAsset(key:"shape",format:"unknown",provenance:try ExchangeFixtures.provenance(),bytes:[1])
        try reject(ExchangeFixtures.replace(source,assets:assets),.unsupportedAssetFormat)
        assets=source.assets;assets.append(NativeInlineAsset(key:"https://host/file",format:"opaque.native.v1",provenance:try ExchangeFixtures.provenance(),bytes:[]))
        try reject(ExchangeFixtures.replace(source,assets:assets),.unsupportedReference)
        let bytes=try ExchangeFixtures.encode(source)
        #expect(throws:ExchangeError.unsupportedAssetFormat) { try ExchangeFixtures.decode(bytes,policy:ExchangeFixtures.policy(formats:[])) }
    }
    @Test func semanticDuplicateAndRequiredCatalogRejection() throws {
        let source=try ExchangeFixtures.document(geometry:false)
        try reject(ExchangeFixtures.replace(source,bodies:source.descriptor.bodies+[source.descriptor.bodies[1]]),.duplicateIdentity)
        let bodies=try [ExchangeFixtures.body("root",mode:.static),ExchangeFixtures.body("é"),ExchangeFixtures.body("e\u{301}")]
        try reject(ExchangeFixtures.replace(source,bodies:bodies),.duplicateIdentity)
        try reject(ExchangeFixtures.replace(source,features:source.descriptor.features+source.descriptor.features),.duplicateFeature)
        let record=try MechanicalExtensionRecord(id:ExchangeFixtures.id(.load,"extension"),schema:"missing",references:[],parameters:[])
        try reject(ExchangeFixtures.replace(source,extensions:[record]),.unsupportedExtension)
        let bytes=try ExchangeFixtures.encode(source)
        #expect(throws:ExchangeError.unsupportedFeature) { try ExchangeFixtures.decode(bytes,policy:ExchangeFixtures.policy(features:[])) }
    }
    @Test func compilerFailureIsNeverDecodedSuccess() throws {
        let source=try ExchangeFixtures.document(geometry:false)
        let bad=try ExchangeFixtures.replace(source,bodies:[ExchangeFixtures.body("root",mode:.static),ExchangeFixtures.body("child",pose:RigidTransform(rotation:.identity,translation:.unitX))])
        let bytes=try ExchangeFixtures.encode(bad)
        #expect(try ExchangeFixtures.decode(bytes).document == bad)
        do { _=try ExchangeFixtures.load(bytes);Issue.record("Inconsistent initial geometry was accepted by recompilation.") }
        catch let error as ExchangeError { if case .compilation(let failure)=error { #expect(!failure.diagnostics.isEmpty) } else { Issue.record("Expected compiler failure, received \(error).") } }
    }
    @Test func cyclicGraphAndStaleInitialRevisionFailRecompile() throws {
        let source=try ExchangeFixtures.document(geometry:false)
        let cycle=try MechanicalJoint(record:JointRecord(id:ExchangeFixtures.id(.joint,"cycle"),parentBody:ExchangeFixtures.id(.body,"child"),childBody:ExchangeFixtures.id(.body,"root"),
            parentAnchor:JointAnchor(frame:ExchangeFixtures.id(.frame,"cycle-parent"),placement:.fixed(.identity)),childAnchor:JointAnchor(frame:ExchangeFixtures.id(.frame,"cycle-child"),placement:.fixed(.identity)),manifold:JointManifold(.fixed)),authority:.fixed)
        let cyclic=try ExchangeFixtures.replace(source,joints:source.descriptor.joints+[cycle])
        #expect(throws:ExchangeError.self) { try ExchangeFixtures.load(ExchangeFixtures.encode(cyclic)) }
        let stale=try ExchangeFixtures.replace(source,state:KinematicState(revision:2,time:0.25,q:[0],v:[2],acceleration:[0]))
        #expect(throws:ExchangeError.self) { try ExchangeFixtures.load(ExchangeFixtures.encode(stale)) }
    }

}
