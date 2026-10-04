import SwiftMechanics

enum ExchangeFixtures {
    static func id(_ kind:EntityKind,_ key:String) throws -> EntityID { try EntityID(kind:kind,key:key) }
    static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute:1e-11,relative:1e-11) }
    static func inertiaPolicy() throws -> InertiaValidationPolicy { try InertiaValidationPolicy(symmetry:tolerance(),physicalityRelative:0) }
    static func policy(bytes:Int=100000,records:Int=1000,elements:Int=10000,string:Int=4096,metadata:Int=100000,
                       allocation:Int=1_000_000,operations:Int=2_000_000,correction:Double=1e-11,
                       schemas:[String]=["spring.v1","dimensions.v1"],features:[String]=["mechanics.compiler.tree","spring.descriptor"],formats:[String]=["opaque.native.v1"]) throws -> ExchangePolicy {
        try ExchangePolicy(maximumWireBytes:bytes,maximumRecords:records,maximumArrayElements:elements,maximumStringBytes:string,
            maximumMetadataBytes:metadata,maximumAllocationBytes:allocation,maximumOperations:operations,maximumUnitComponentCorrection:correction,
            inertiaPolicy:inertiaPolicy(),extensionSchemas:schemas,featureNames:features,assetFormats:formats)
    }
    static func compilationPolicy() throws -> CompilationPolicy {
        try CompilationPolicy(kinematicCapacity:KinematicCapacity(maximumBodies:32,maximumVelocities:96,maximumJacobianScalars:18432),
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance(),chartRankRelative:1e-9,characteristicLengthMeters:1),inertiaPolicy:inertiaPolicy(),
            translationTolerance:tolerance(),rotationTolerance:tolerance(),maximumRecords:1000,maximumIdentifierBytes:100000,maximumSparsityEntries:10000,
            maximumDependencyEntries:10000,maximumExtensionRecords:32,maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),target:.nativeCPU)
    }
    static func provenance(_ source:String="CAD源",revision:UInt64=7) throws -> SourceProvenance { try SourceProvenance(source:source,revision:revision) }
    static func assets() throws -> [NativeInlineAsset] {
        [NativeInlineAsset(key:"shape",format:"opaque.native.v1",provenance:try provenance(),bytes:[0,255,17]),
         NativeInlineAsset(key:"display",format:"opaque.native.v1",provenance:try provenance(),bytes:[1,2]),
         NativeInlineAsset(key:"proxy",format:"opaque.native.v1",provenance:try provenance(),bytes:[128,255])]
    }
    static func body(_ key:String,planar:Bool=false,mode:BodyMotionMode = .dynamic,pose:RigidTransform = .identity,representations:Bool=false) throws -> MechanicalBody {
        let source=try provenance()
        let reps=try BodyRepresentations(geometricShape:representations ? GeometryRepresentation(kind:.geometricShape,assetKey:"shape",provenance:source,quality:.exact) : nil,
            displayGeometry:representations ? GeometryRepresentation(kind:.displayGeometry,assetKey:"display",provenance:source,quality:.approximation(maximumDeviationMeters:0.01)) : nil,
            collisionGeometry:representations ? GeometryRepresentation(kind:.collisionGeometry,assetKey:"proxy",provenance:source,quality:.approximation(maximumDeviationMeters:0.0005)) : nil)
        let quality=InertialQuality.approximation(try InertialApproximation(maximumMassErrorKilograms:0.001,maximumCenterErrorMeters:0.002,maximumInertiaElementErrorKilogramMetersSquared:0.003))
        if planar {
            return .planar(try BodyRecord2D(id:id(.body,key),frame:id(.frame,key+"-frame"),mode:mode,
                bodyToWorld:PlanarPose(x:pose.translation.x,y:pose.translation.y,angle:pose.rotation.rotationVector().z),representations:reps,
                inertia:mode == .static ? nil : InertialRepresentation2D(properties:MassProperties2D(mass:2,centerX:0.1,centerY:0.2,polarInertiaAtCenter:3),provenance:source,quality:quality)))
        }
        let inertia:InertialRepresentation3D?
        if mode == .static { inertia=nil }
        else { inertia=try InertialRepresentation3D(properties:MassProperties3D(mass:2,centerOfMass:Vector3(0.1,0.2,0.3),inertiaAtCenter:Matrix3(2,0,0,0,3,0,0,0,4),policy:inertiaPolicy(),origin:.compound(overlapPolicy:.additiveOverlappingMaterials)),provenance:source,quality:quality) }
        return .spatial(try BodyRecord3D(id:id(.body,key),frame:id(.frame,key+"-frame"),mode:mode,bodyToWorld:pose,representations:reps,inertia:inertia))
    }
    static func joint(specification:JointSpecification = .revolute(axis:.unitZ),prescribed:Bool=false,offset:Bool=false) throws -> MechanicalJoint {
        let manifold=try JointManifold(specification)
        return try MechanicalJoint(record:JointRecord(id:id(.joint,"joint"),parentBody:id(.body,"root"),childBody:id(.body,"child"),
            parentAnchor:JointAnchor(frame:id(.frame,"parent-anchor"),placement:prescribed ? .prescribed : .fixed(.identity)),
            childAnchor:JointAnchor(frame:id(.frame,"child-anchor"),placement:.fixed(RigidTransform(rotation:.identity,translation:offset ? Vector3(-1,0,0) : .zero))),
            manifold:manifold),authority:manifold.velocityCount == 0 ? .fixed : .dynamicState)
    }
    static func document(planar:Bool=false,specification:JointSpecification = .revolute(axis:.unitZ),q:[Double]=[0],v:[Double]=[2],
                         extensions:[MechanicalExtensionRecord]=[],prescribed:Bool=false,revision:UInt64=3,offset:Bool=false,geometry:Bool=true) throws -> NativeMechanicalDocument {
        let root=try body("root",planar:planar,mode:.static)
        let child=try body("child",planar:planar,pose:RigidTransform(rotation:.identity,translation:offset ? .unitX : .zero),representations:geometry)
        let anchors:[PrescribedAnchorState]
        if prescribed { anchors=[try PrescribedAnchorState(frame:id(.frame,"parent-anchor"),time:0.25,motion:.stationary(pose:.identity))] } else { anchors=[] }
        let features=[try FeatureRequirement(feature:"mechanics.compiler.tree",operation:.descriptorValidation,domain:planar ? .planarTree : .spatialTree,precision:.float64,backend:.referenceCPU,target:.nativeCPU)]
        let d=try MechanicalDescriptor(identity:"model",revision:revision,bodies:[root,child],joints:[joint(specification:specification,prescribed:prescribed,offset:offset)],
            root:id(.body,"root"),rootBase:.fixed,rootAuthority:.fixed,worldFrame:id(.frame,"world"),
            initialState:KinematicState(revision:revision,time:0.25,q:q,v:v,acceleration:Array(repeating:0,count:v.count),prescribedAnchors:anchors),
            representationRequirements:geometry ? [BodyRepresentationRequirement(body:id(.body,"child"),geometry:[.geometricShape,.displayGeometry,.collisionGeometry],inertia:.required)] : [],features:features,extensions:extensions)
        return NativeMechanicalDocument(descriptor:d,assets:geometry ? try assets() : [])
    }
    static func replace(_ value:NativeMechanicalDocument,identity:String?=nil,revision:UInt64?=nil,bodies:[MechanicalBody]?=nil,joints:[MechanicalJoint]?=nil,
                        state:KinematicState?=nil,extensions:[MechanicalExtensionRecord]?=nil,features:[FeatureRequirement]?=nil,assets:[NativeInlineAsset]?=nil) throws -> NativeMechanicalDocument {
        let d=value.descriptor
        return try NativeMechanicalDocument(descriptor:MechanicalDescriptor(identity:identity ?? d.identity,revision:revision ?? d.revision,bodies:bodies ?? d.bodies,joints:joints ?? d.joints,
            root:d.root,rootBase:d.rootBase,rootAuthority:d.rootAuthority,worldFrame:d.worldFrame,initialState:state ?? d.initialState,
            representationRequirements:d.representationRequirements,features:features ?? d.features,extensions:extensions ?? d.extensions),assets:assets ?? value.assets)
    }
    static func encode(_ document:NativeMechanicalDocument,policy:ExchangePolicy?=nil) throws -> [UInt8] {
        var work=ExchangeWork(policy:try policy ?? self.policy());let codec:any NativeModelCoding=SMNXNativeModelCodec()
        return try codec.encode(document:document,work:&work)
    }
    static func decode(_ bytes:[UInt8],policy:ExchangePolicy?=nil) throws -> NativeDecodeResult {
        var work=ExchangeWork(policy:try policy ?? self.policy());let codec:any NativeModelCoding=SMNXNativeModelCodec()
        return try codec.decode(bytes:bytes,work:&work)
    }
    static func load(_ bytes:[UInt8]) throws -> NativeLoadedModel {
        var work=ExchangeWork(policy:try policy());let loader:any NativeModelLoading=ReferenceNativeModelLoader(compiler:ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()),codec:SMNXNativeModelCodec())
        return try loader.load(bytes:bytes,compilationPolicy:compilationPolicy(),work:&work)
    }
    static func setInteger(_ value:UInt64,in bytes:inout [UInt8],at offset:Int) {
        for i in 0..<8 { bytes[offset+i]=UInt8(truncatingIfNeeded:value >> (i*8)) }
    }
}
