
internal struct NativeWireReader {
    let bytes:[UInt8]
    var work:ExchangeWork
    var offset=0
    var shape=ExchangeShapeBudget()
    var maximumCorrection=0.0
    var correctedRecords=0
    mutating func byte() throws(ExchangeError) -> UInt8 {
        try work.charge(1);guard offset < bytes.count else { throw .truncated(offset:offset) }
        let value=bytes[offset];offset += 1;return value
    }
    mutating func integer() throws(ExchangeError) -> UInt64 {
        var value:UInt64=0;for shift in stride(from:0,to:64,by:8) { value |= UInt64(try byte()) << shift };return value
    }
    mutating func scalar() throws(ExchangeError) -> Double {
        let value=Double(bitPattern:try integer());guard value.isFinite else { throw .nonfiniteScalar(offset:offset-8) };return value
    }
    mutating func boolean() throws(ExchangeError) -> Bool {
        switch try byte() { case 0:return false;case 1:return true;default:throw .unknownTag(offset:offset-1) }
    }
    mutating func length() throws(ExchangeError) -> Int {
        let raw=try integer();guard raw <= UInt64(Int.max) else { throw .arithmeticOverflow };return Int(raw)
    }
    func end(_ count:Int) throws(ExchangeError) -> Int {
        let result=try ExchangeWork.sum(offset,count);guard result <= bytes.count else { throw .truncated(offset:offset) };return result
    }
    mutating func text() throws(ExchangeError) -> String {
        let count=try length();try shape.text(count,policy:work.policy);let last=try end(count)
        try work.charge(ExchangeWork.product(count,2));try NativeUTF8Validation.validate(bytes:bytes,range:offset..<last)
        try work.allocate(count)
        let value=String(decoding:bytes[offset..<last],as:UTF8.self);offset=last;return value
    }
    mutating func array<T>(minimum:Int,record:Bool=true,maximum:Int?=nil,
                           _ read:(inout NativeWireReader) throws(ExchangeError) -> T) throws(ExchangeError) -> [T] {
        let count=try length();try shape.count(count,record:record,policy:work.policy)
        if let maximum { guard count <= maximum else { throw .producerRecord(offset:offset) } }
        _=try end(ExchangeWork.product(count,minimum))
        try work.allocate(ExchangeWork.product(count,MemoryLayout<T>.stride));try work.charge(count)
        var values:[T]=[];values.reserveCapacity(count)
        for _ in 0..<count { values.append(try read(&self)) };return values
    }
    mutating func blob() throws(ExchangeError) -> [UInt8] {
        let count=try length();guard count <= work.policy.maximumWireBytes else { throw .resourceLimit(resource:.wireBytes,limit:work.policy.maximumWireBytes) }
        let last=try end(count);try work.allocate(count);try work.charge(count)
        let result=Array(bytes[offset..<last]);offset=last;return result
    }
    mutating func correction(_ value:Double) throws(ExchangeError) {
        try work.charge(32)
        guard value <= work.policy.maximumUnitComponentCorrection else { throw .normalizationExceeded(value:value,limit:work.policy.maximumUnitComponentCorrection) }
        maximumCorrection=max(maximumCorrection,value);if value > 0 { correctedRecords=try ExchangeWork.sum(correctedRecords,1) }
    }
    mutating func vector() throws(ExchangeError) -> Vector3 {
        let x=try scalar(),y=try scalar(),z=try scalar();return try exchangeBuild(at:offset) { try Vector3(x,y,z) }
    }
    mutating func matrix() throws(ExchangeError) -> Matrix3 {
        let a=try scalar(),b=try scalar(),c=try scalar(),d=try scalar(),e=try scalar(),f=try scalar(),g=try scalar(),h=try scalar(),i=try scalar()
        return try exchangeBuild(at:offset) { try Matrix3(a,b,c,d,e,f,g,h,i) }
    }
    mutating func transform() throws(ExchangeError) -> RigidTransform {
        let w=try scalar(),x=try scalar(),y=try scalar(),z=try scalar()
        let q=try exchangeBuild(at:offset) { try UnitQuaternion(w:w,x:x,y:y,z:z) }
        try correction(max(abs(q.w-w),max(abs(q.x-x),max(abs(q.y-y),abs(q.z-z)))))
        return RigidTransform(rotation:q,translation:try vector())
    }
    mutating func spatial() throws(ExchangeError) -> SpatialMotion { SpatialMotion(angular:try vector(),linear:try vector()) }
    mutating func motion() throws(ExchangeError) -> FrameMotion { FrameMotion(pose:try transform(),velocity:try spatial(),acceleration:try spatial()) }
    mutating func id() throws(ExchangeError) -> EntityID {
        let kind=try NativeWireTags.entityKind(byte(),at:offset),key=try text()
        return try exchangeBuild(at:offset) { try EntityID(kind:kind,key:key) }
    }
    mutating func provenance() throws(ExchangeError) -> SourceProvenance {
        let source=try text(),revision=try integer();return try exchangeBuild(at:offset) { try SourceProvenance(source:source,revision:revision) }
    }
    mutating func representation() throws(ExchangeError) -> GeometryRepresentation? {
        guard try boolean() else { return nil }
        let kind=try NativeWireTags.representationKind(byte(),at:offset),key=try text(),source=try provenance()
        let quality:RepresentationQuality
        switch try byte() { case 0:quality = .exact;case 1:quality = .approximation(maximumDeviationMeters:try scalar());default:throw .unknownTag(offset:offset-1) }
        return try exchangeBuild(at:offset) { try GeometryRepresentation(kind:kind,assetKey:key,provenance:source,quality:quality) }
    }
    mutating func representations() throws(ExchangeError) -> BodyRepresentations {
        let geometry=try representation(),display=try representation(),collision=try representation()
        return try exchangeBuild(at:offset) { try BodyRepresentations(geometricShape:geometry,displayGeometry:display,collisionGeometry:collision) }
    }
    mutating func quality() throws(ExchangeError) -> InertialQuality {
        switch try byte() {
        case 0:return .exact
        case 1:
            let m=try scalar(),c=try scalar(),i=try scalar()
            return .approximation(try exchangeBuild(at:offset) { try InertialApproximation(maximumMassErrorKilograms:m,maximumCenterErrorMeters:c,maximumInertiaElementErrorKilogramMetersSquared:i) })
        default:throw .unknownTag(offset:offset-1)
        }
    }
    mutating func origin() throws(ExchangeError) -> MassPropertyOrigin {
        switch try byte() {
        case 0:return .supplied
        case 1:return .analyticPrimitive
        case 2:switch try byte() { case 0:return .compound(overlapPolicy:.requireDisjointBoundingBoxes);case 1:return .compound(overlapPolicy:.additiveOverlappingMaterials);default:throw .unknownTag(offset:offset-1) }
        default:throw .unknownTag(offset:offset-1)
        }
    }
    mutating func body() throws(ExchangeError) -> MechanicalBody {
        let dimension=try byte();guard dimension <= 1 else { throw .unknownTag(offset:offset-1) }
        let identity=try id(),frame=try id(),mode=try NativeWireTags.bodyMode(byte(),at:offset)
        if dimension == 0 {
            let x=try scalar(),y=try scalar(),a=try scalar()
            let pose=try exchangeBuild(at:offset) { try PlanarPose(x:x,y:y,angle:a) }
            let reps=try representations();let inertia:InertialRepresentation2D?
            if try boolean() {
                let mass=try scalar(),cx=try scalar(),cy=try scalar(),polar=try scalar(),source=try provenance(),q=try quality()
                let properties=try exchangeBuild(at:offset) { try MassProperties2D(mass:mass,centerX:cx,centerY:cy,polarInertiaAtCenter:polar) }
                inertia=InertialRepresentation2D(properties:properties,provenance:source,quality:q)
            } else { inertia=nil }
            return .planar(try exchangeBuild(at:offset) { try BodyRecord2D(id:identity,frame:frame,mode:mode,bodyToWorld:pose,representations:reps,inertia:inertia) })
        }
        let pose=try transform(),reps=try representations();let inertia:InertialRepresentation3D?
        if try boolean() {
            let mass=try scalar(),center=try vector(),tensor=try matrix(),from=try origin(),source=try provenance(),q=try quality(),policy=work.policy.inertiaPolicy
            let properties=try exchangeBuild(at:offset) { try MassProperties3D(mass:mass,centerOfMass:center,inertiaAtCenter:tensor,policy:policy,origin:from) }
            guard properties.inertiaAtCenter == tensor else { throw .producerRecord(offset:offset) }
            inertia=InertialRepresentation3D(properties:properties,provenance:source,quality:q)
        } else { inertia=nil }
        return .spatial(try exchangeBuild(at:offset) { try BodyRecord3D(id:identity,frame:frame,mode:mode,bodyToWorld:pose,representations:reps,inertia:inertia) })
    }
    mutating func anchor() throws(ExchangeError) -> JointAnchor {
        let frame=try id();let placement:AnchorPlacement
        switch try byte() { case 0:placement = .fixed(try transform());case 1:placement = .prescribed;default:throw .unknownTag(offset:offset-1) }
        return try exchangeBuild(at:offset) { try JointAnchor(frame:frame,placement:placement) }
    }
    mutating func manifold() throws(ExchangeError) -> JointManifold {
        let kind=try NativeWireTags.jointKind(byte(),at:offset)
        let axes=try array(minimum:33,maximum:6) { (r:inout NativeWireReader) throws(ExchangeError) in
            NativeWireAxis(kind:try NativeWireTags.axisKind(r.byte(),at:r.offset),direction:try r.vector(),pitch:try r.scalar())
        }
        let expected:Int
        switch kind { case .fixed,.spherical,.sixDOF:expected=0;case .revolute,.prismatic,.screw:expected=1;case .universal,.cylindrical:expected=2;case .planar:expected=3;case .custom:expected=axes.count }
        guard axes.count == expected else { throw .producerRecord(offset:offset) }
        let specification:JointSpecification
        switch kind {
        case .fixed:specification = .fixed
        case .revolute:specification = .revolute(axis:axes[0].direction)
        case .prismatic:specification = .prismatic(axis:axes[0].direction)
        case .spherical:specification = .spherical
        case .universal:specification = .universal(firstAxis:axes[0].direction,secondAxis:axes[1].direction)
        case .cylindrical:specification = .cylindrical(axis:axes[0].direction)
        case .planar:specification = .planar(firstTranslationAxis:axes[0].direction,secondTranslationAxis:axes[1].direction)
        case .screw:specification = .screw(axis:axes[0].direction,pitchMetersPerRadian:axes[0].pitch)
        case .sixDOF:specification = .sixDOF
        case .custom:
            try work.allocate(ExchangeWork.product(axes.count,MemoryLayout<JointAxis>.stride))
            var converted:[JointAxis]=[];converted.reserveCapacity(axes.count)
            for a in axes { converted.append(try exchangeBuild(at:offset) { try JointAxis(kind:a.kind,direction:a.direction,pitchMetersPerRadian:a.pitch) }) }
            specification = .custom(orderedAxes:converted)
        }
        try work.allocate(ExchangeWork.product(axes.count,MemoryLayout<JointAxis>.stride))
        let manifold=try exchangeBuild(at:offset) { try JointManifold(specification) }
        for i in axes.indices {
            let actual=manifold.orderedAxes[i],original=axes[i]
            guard actual.kind == original.kind,actual.pitchMetersPerRadian.bitPattern == original.pitch.bitPattern else { throw .producerRecord(offset:offset) }
            try correction(max(abs(actual.direction.x-original.direction.x),max(abs(actual.direction.y-original.direction.y),abs(actual.direction.z-original.direction.z))))
        }
        return manifold
    }
    mutating func joint() throws(ExchangeError) -> MechanicalJoint {
        let identity=try id(),parent=try id(),child=try id(),pa=try anchor(),ca=try anchor(),m=try manifold(),authority=try NativeWireTags.authority(byte(),at:offset)
        return MechanicalJoint(record:try exchangeBuild(at:offset) { try JointRecord(id:identity,parentBody:parent,childBody:child,parentAnchor:pa,childAnchor:ca,manifold:m) },authority:authority)
    }
    mutating func doubles() throws(ExchangeError) -> [Double] { try array(minimum:8,record:false) { (r:inout NativeWireReader) throws(ExchangeError) in try r.scalar() } }
    mutating func state() throws(ExchangeError) -> KinematicState {
        let revision=try integer(),time=try scalar(),q=try doubles(),v=try doubles(),a=try doubles()
        let anchors=try array(minimum:170) { (r:inout NativeWireReader) throws(ExchangeError) in
            let frame=try r.id(),time=try r.scalar(),motion=try r.motion()
            return try exchangeBuild(at:r.offset) { try PrescribedAnchorState(frame:frame,time:time,motion:motion) }
        }
        return try exchangeBuild(at:offset) { try KinematicState(revision:revision,time:time,q:q,v:v,acceleration:a,prescribedAnchors:anchors) }
    }
    mutating func dimension() throws(ExchangeError) -> PhysicalDimension {
        try PhysicalDimension(length:Int8(bitPattern:byte()),mass:Int8(bitPattern:byte()),time:Int8(bitPattern:byte()),angle:Int8(bitPattern:byte()),electricCurrent:Int8(bitPattern:byte()),temperature:Int8(bitPattern:byte()),amount:Int8(bitPattern:byte()),luminousIntensity:Int8(bitPattern:byte()))
    }
    mutating func feature() throws(ExchangeError) -> FeatureRequirement {
        let name=try text(),operation=try NativeWireTags.operation(byte(),at:offset),domain=try NativeWireTags.domain(byte(),at:offset),precision=try NativeWireTags.precision(byte(),at:offset),backend=try NativeWireTags.backend(byte(),at:offset),target=try NativeWireTags.compilerTarget(byte(),at:offset)
        return try exchangeBuild(at:offset) { try FeatureRequirement(feature:name,operation:operation,domain:domain,precision:precision,backend:backend,target:target) }
    }
    mutating func extensionRecord() throws(ExchangeError) -> MechanicalExtensionRecord {
        let identity=try id(),schema=try text()
        let refs=try array(minimum:10) { (r:inout NativeWireReader) throws(ExchangeError) in try r.id() }
        let parameters=try array(minimum:25) { (r:inout NativeWireReader) throws(ExchangeError) in
            let name=try r.text(),value=try r.scalar(),dimension=try r.dimension()
            return try exchangeBuild(at:r.offset) { try ExtensionParameter(name:name,value:value,dimension:dimension) }
        }
        return try exchangeBuild(at:offset) { try MechanicalExtensionRecord(id:identity,schema:schema,references:refs,parameters:parameters) }
    }
    mutating func document() throws(ExchangeError) -> NativeMechanicalDocument {
        guard try byte() == 83,try byte() == 77,try byte() == 78,try byte() == 88 else { throw .malformedHeader }
        let version=try integer();guard version == 1 else { throw .unsupportedVersion(version) }
        let units=try byte();guard units == 1 else { throw .unsupportedUnits(units) }
        let identity=try text(),revision=try integer()
        let bodies=try array(minimum:50) { (r:inout NativeWireReader) throws(ExchangeError) in try r.body() }
        let joints=try array(minimum:62) { (r:inout NativeWireReader) throws(ExchangeError) in try r.joint() }
        let root=try id(),base=try NativeWireTags.baseLayout(byte(),at:offset),authority=try NativeWireTags.authority(byte(),at:offset),world=try id(),state=try state()
        let requirements=try array(minimum:19) { (r:inout NativeWireReader) throws(ExchangeError) in
            let body=try r.id(),geometry=try r.array(minimum:1) { (r:inout NativeWireReader) throws(ExchangeError) in try NativeWireTags.representationKind(r.byte(),at:r.offset) },inertia=try NativeWireTags.inertiaRequirement(r.byte(),at:r.offset)
            return BodyRepresentationRequirement(body:body,geometry:geometry,inertia:inertia)
        }
        let features=try array(minimum:14) { (r:inout NativeWireReader) throws(ExchangeError) in try r.feature() }
        let extensions=try array(minimum:35) { (r:inout NativeWireReader) throws(ExchangeError) in try r.extensionRecord() }
        let descriptor=try exchangeBuild(at:offset) { try MechanicalDescriptor(identity:identity,revision:revision,bodies:bodies,joints:joints,root:root,rootBase:base,rootAuthority:authority,worldFrame:world,initialState:state,representationRequirements:requirements,features:features,extensions:extensions) }
        let assets=try array(minimum:43) { (r:inout NativeWireReader) throws(ExchangeError) in
            NativeInlineAsset(key:try r.text(),format:try r.text(),provenance:try r.provenance(),bytes:try r.blob())
        }
        guard offset == bytes.count else { throw .trailingBytes(offset:offset) }
        return NativeMechanicalDocument(descriptor:descriptor,assets:assets)
    }
}
