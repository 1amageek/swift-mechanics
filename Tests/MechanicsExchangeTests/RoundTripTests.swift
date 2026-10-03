import Testing
import MechanicsExchange
import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints
import MechanicsCompiler

@Suite struct RoundTripTests {
    @Test func spatialAndPlanarRecompileAndIndependentCircularMotion() throws {
        for planar in [false,true] {
            let source=try ExchangeFixtures.document(planar:planar,offset:true)
            let loaded=try ExchangeFixtures.load(ExchangeFixtures.encode(source))
            let original=try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(source.descriptor,policy:ExchangeFixtures.compilationPolicy())
            #expect(loaded.decoded.document == source)
            #expect(loaded.model.report == original.report && loaded.model.tree.layout == original.tree.layout)
            #expect(loaded.model.sparsity == original.sparsity && loaded.model.manifest == original.manifest)
            #expect(loaded.model.report.structuralTreeRank.rank == (planar ? 5 : 11))
            let motion=try loaded.model.initialSnapshot.body(ExchangeFixtures.id(.body,"child")).motion
            #expect(motion.pose.translation == .unitX)
            #expect(motion.velocity.linear == (try Vector3(0,2,0)))
            #expect(motion.acceleration.linear == (try Vector3(-4,0,0)))
            #expect(motion.velocity.angular.z == 2)
        }
    }
    @Test func everyCurrentJointFormulationRetainsQVAndAxes() throws {
        let custom=try [JointAxis(kind:.prismatic,direction:.unitX),JointAxis(kind:.revolute,direction:.unitZ)]
        let cases:[(JointSpecification,[Double],[Double])]=[
            (.fixed,[],[]),(.revolute(axis:.unitZ),[0],[0]),(.prismatic(axis:.unitX),[0],[0]),
            (.spherical,[1,0,0,0],[0,0,0]),(.universal(firstAxis:.unitX,secondAxis:.unitY),[0,0],[0,0]),
            (.cylindrical(axis:.unitZ),[0,0],[0,0]),(.planar(firstTranslationAxis:.unitX,secondTranslationAxis:.unitY),[0,0,0],[0,0,0]),
            (.screw(axis:.unitZ,pitchMetersPerRadian:0.125),[0],[0]),(.sixDOF,[0,0,0,1,0,0,0],[0,0,0,0,0,0]),
            (.custom(orderedAxes:custom),[0,0],[0,0])]
        for (spec,q,v) in cases {
            let source=try ExchangeFixtures.document(specification:spec,q:q,v:v,geometry:false)
            let loaded=try ExchangeFixtures.load(ExchangeFixtures.encode(source))
            #expect(loaded.decoded.document == source)
            #expect(loaded.model.report.positionCount == q.count && loaded.model.report.velocityCount == v.count)
            #expect(loaded.model.descriptor.joints[0].record.manifold == source.descriptor.joints[0].record.manifold)
        }
    }
    @Test func floatingRootLayoutsAndPrescribedAnchorSample() throws {
        for planar in [false,true] {
            let root=try ExchangeFixtures.body("root",planar:planar)
            let q:[Double]=planar ? [0,0,0] : [0,0,0,1,0,0,0],v=Array(repeating:0.0,count:planar ? 3 : 6)
            let d=try MechanicalDescriptor(identity:"floating",revision:3,bodies:[root],joints:[],root:ExchangeFixtures.id(.body,"root"),
                rootBase:planar ? .planarFloating : .spatialFloating,rootAuthority:.dynamicState,worldFrame:ExchangeFixtures.id(.frame,"world"),
                initialState:KinematicState(revision:3,time:0,q:q,v:v,acceleration:v),representationRequirements:[],features:[],extensions:[])
            let loaded=try ExchangeFixtures.load(ExchangeFixtures.encode(NativeMechanicalDocument(descriptor:d,assets:[])))
            #expect(loaded.model.report.positionCount == q.count && loaded.model.report.velocityCount == v.count)
            #expect(loaded.model.report.structuralTreeRank.rank == 0)
        }
        let source=try ExchangeFixtures.document(prescribed:true,geometry:false)
        let loaded=try ExchangeFixtures.load(ExchangeFixtures.encode(source))
        #expect(loaded.decoded.document.descriptor.initialState.prescribedAnchors == source.descriptor.initialState.prescribedAnchors)
        #expect(try loaded.model.initialSnapshot.body(ExchangeFixtures.id(.body,"child")).motion.velocity.angular.z == 2)
    }
    @Test func requiredExtensionRealValidatorAndSIParameterRoundTrip() throws {
        let source=try ExchangeFixtures.document(geometry:false)
        let parameters=try [ExtensionParameter(name:"stiffness",value:1200,dimension:PhysicalDimension(mass:1,time:-2)),ExtensionParameter(name:"restLength",value:0.25,dimension:.length)]
        let record=try MechanicalExtensionRecord(id:ExchangeFixtures.id(.load,"spring"),schema:"spring.v1",references:[ExchangeFixtures.id(.body,"root"),ExchangeFixtures.id(.body,"child")],parameters:parameters)
        let feature=try FeatureRequirement(feature:"spring.descriptor",operation:.descriptorValidation,domain:.spatialTree,precision:.float64,backend:.referenceCPU,target:.nativeCPU)
        let document=try ExchangeFixtures.replace(source,extensions:[record],features:source.descriptor.features+[feature]),bytes=try ExchangeFixtures.encode(document)
        var work=ExchangeWork(policy:try ExchangeFixtures.policy())
        let loader:any NativeModelLoading=ReferenceNativeModelLoader(compiler:ReferenceMechanicalCompiler(extensions:try ExchangeSpringValidator()),codec:SMNXNativeModelCodec())
        let loaded=try loader.load(bytes:bytes,compilationPolicy:ExchangeFixtures.compilationPolicy(),work:&work)
        #expect(loaded.decoded.document == document && loaded.model.report.extensionCount == 1)
        #expect(loaded.model.descriptor.extensions[0].parameters == parameters)
        #expect(throws:ExchangeError.self) { try ExchangeFixtures.load(bytes) }
        let badParameters=try [ExtensionParameter(name:"stiffness",value:-1,dimension:PhysicalDimension(mass:1,time:-2)),parameters[1]]
        let badRecord=try MechanicalExtensionRecord(id:record.id,schema:record.schema,references:record.references,parameters:badParameters)
        let bad=try ExchangeFixtures.encode(ExchangeFixtures.replace(document,extensions:[badRecord]))
        #expect(throws:ExchangeError.self) { try loader.load(bytes:bad,compilationPolicy:ExchangeFixtures.compilationPolicy(),work:&work) }
    }
    @Test func allDimensionExponentsAndFeatureTagsAreWireSemantics() throws {
        let dimension=PhysicalDimension(length:-2,mass:3,time:-4,angle:5,electricCurrent:-6,temperature:7,amount:-8,luminousIntensity:9)
        let record=try MechanicalExtensionRecord(id:ExchangeFixtures.id(.sensor,"dimensions"),schema:"dimensions.v1",references:[],parameters:[ExtensionParameter(name:"dimension",value:0.5,dimension:dimension)])
        let source=try ExchangeFixtures.replace(ExchangeFixtures.document(geometry:false),extensions:[record])
        #expect(try ExchangeFixtures.decode(ExchangeFixtures.encode(source)).document == source)
    }
    @Test func recompiledRevisionRetainsExactMigrationMeaning() throws {
        let source=try ExchangeFixtures.document(geometry:false),original=try ExchangeFixtures.load(ExchangeFixtures.encode(source)).model
        let next=try ExchangeFixtures.replace(source,revision:4,state:KinematicState(revision:4,time:0.25,q:[0],v:[2],acceleration:[0]))
        let target=try ExchangeFixtures.load(ExchangeFixtures.encode(next)).model,updater=ReferenceModelRevisionUpdater()
        let transition=try updater.transition(from:original,to:target,policy:.preserveIfKinematicsUnchanged)
        #expect(transition.kind == .revisionOnly && transition.invalidatedCaches.isEmpty)
        let state=try original.makeState(KinematicState(revision:3,time:1,q:[0.4],v:[3],acceleration:[5]))
        let migrated=try updater.migrate(state,using:transition,to:target)
        #expect(migrated.stamp.revision == 4 && migrated.state.q == [0.4] && migrated.state.v == [3])
        #expect(try target.evaluate(migrated).body(ExchangeFixtures.id(.body,"child")).motion == original.evaluate(state).body(ExchangeFixtures.id(.body,"child")).motion)
    }
}
