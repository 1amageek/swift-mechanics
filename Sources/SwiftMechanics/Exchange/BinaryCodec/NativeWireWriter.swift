
internal struct NativeWireWriter {
    var work:ExchangeWork
    let measuring:Bool
    var bytes:[UInt8]=[]
    var size=0
    var shape=ExchangeShapeBudget()
    init(work:ExchangeWork,measuring:Bool,reservation:Int=0) throws(ExchangeError) {
        self.work=work;self.measuring=measuring
        if !measuring { try self.work.allocate(reservation);bytes.reserveCapacity(reservation) }
    }
    mutating func byte(_ value:UInt8) throws(ExchangeError) {
        try work.charge(1);let next=try ExchangeWork.sum(size,1)
        guard next <= work.policy.maximumWireBytes else { throw .resourceLimit(resource:.wireBytes,limit:work.policy.maximumWireBytes) }
        size=next;if !measuring { bytes.append(value) }
    }
    mutating func integer(_ value:UInt64) throws(ExchangeError) {
        for shift in stride(from:0,to:64,by:8) { try byte(UInt8(truncatingIfNeeded:value >> shift)) }
    }
    mutating func scalar(_ value:Double) throws(ExchangeError) {
        guard value.isFinite else { throw .nonfiniteScalar(offset:size) };try integer(value.bitPattern)
    }
    mutating func text(_ value:String) throws(ExchangeError) {
        var count=0
        for _ in value.utf8 {
            try work.charge(1);count=try ExchangeWork.sum(count,1)
            guard count <= work.policy.maximumStringBytes else { throw .resourceLimit(resource:.stringBytes,limit:work.policy.maximumStringBytes) }
        }
        try shape.text(count,policy:work.policy);try integer(UInt64(count))
        for value in value.utf8 { try byte(value) }
    }
    mutating func count(_ value:Int,record:Bool=true) throws(ExchangeError) {
        try shape.count(value,record:record,policy:work.policy);try integer(UInt64(value))
    }
    mutating func vector(_ v:Vector3) throws(ExchangeError) { try scalar(v.x);try scalar(v.y);try scalar(v.z) }
    mutating func matrix(_ m:Matrix3) throws(ExchangeError) {
        try scalar(m.m00);try scalar(m.m01);try scalar(m.m02);try scalar(m.m10);try scalar(m.m11);try scalar(m.m12);try scalar(m.m20);try scalar(m.m21);try scalar(m.m22)
    }
    mutating func transform(_ t:RigidTransform) throws(ExchangeError) {
        try scalar(t.rotation.w);try scalar(t.rotation.x);try scalar(t.rotation.y);try scalar(t.rotation.z);try vector(t.translation)
    }
    mutating func spatial(_ value:SpatialMotion) throws(ExchangeError) { try vector(value.angular);try vector(value.linear) }
    mutating func motion(_ value:FrameMotion) throws(ExchangeError) { try transform(value.pose);try spatial(value.velocity);try spatial(value.acceleration) }
    mutating func id(_ value:EntityID) throws(ExchangeError) { try byte(NativeWireTags.entityKind(value.kind));try text(value.key) }
    mutating func provenance(_ value:SourceProvenance) throws(ExchangeError) { try text(value.source);try integer(value.revision) }
    mutating func representation(_ value:GeometryRepresentation?) throws(ExchangeError) {
        guard let value else { try byte(0);return };try byte(1)
        try byte(NativeWireTags.representationKind(value.kind));try text(value.assetKey);try provenance(value.provenance)
        switch value.quality { case .exact: try byte(0);case .approximation(let deviation):try byte(1);try scalar(deviation) }
    }
    mutating func representations(_ value:BodyRepresentations) throws(ExchangeError) {
        try representation(value.geometricShape);try representation(value.displayGeometry);try representation(value.collisionGeometry)
    }
    mutating func quality(_ value:InertialQuality) throws(ExchangeError) {
        switch value {
        case .exact:try byte(0)
        case .approximation(let q):try byte(1);try scalar(q.maximumMassErrorKilograms);try scalar(q.maximumCenterErrorMeters);try scalar(q.maximumInertiaElementErrorKilogramMetersSquared)
        }
    }
    mutating func origin(_ value:MassPropertyOrigin) throws(ExchangeError) {
        switch value {
        case .supplied:try byte(0)
        case .analyticPrimitive:try byte(1)
        case .compound(let policy):try byte(2);switch policy { case .requireDisjointBoundingBoxes:try byte(0);case .additiveOverlappingMaterials:try byte(1) }
        }
    }
    mutating func body(_ value:MechanicalBody) throws(ExchangeError) {
        switch value {
        case .planar(let b):
            try byte(0);try id(b.id);try id(b.frame);try byte(NativeWireTags.bodyMode(b.mode))
            try scalar(b.bodyToWorld.x);try scalar(b.bodyToWorld.y);try scalar(b.bodyToWorld.angle);try representations(b.representations)
            if let i=b.inertia { try byte(1);try scalar(i.properties.mass);try scalar(i.properties.centerX);try scalar(i.properties.centerY);try scalar(i.properties.polarInertiaAtCenter);try provenance(i.provenance);try quality(i.quality) }
            else { try byte(0) }
        case .spatial(let b):
            try byte(1);try id(b.id);try id(b.frame);try byte(NativeWireTags.bodyMode(b.mode));try transform(b.bodyToWorld);try representations(b.representations)
            if let i=b.inertia { try byte(1);try scalar(i.properties.mass);try vector(i.properties.centerOfMass);try matrix(i.properties.inertiaAtCenter);try origin(i.properties.origin);try provenance(i.provenance);try quality(i.quality) }
            else { try byte(0) }
        }
    }
    mutating func anchor(_ value:JointAnchor) throws(ExchangeError) {
        try id(value.frame);switch value.placement { case .fixed(let pose):try byte(0);try transform(pose);case .prescribed:try byte(1) }
    }
    mutating func joint(_ value:MechanicalJoint) throws(ExchangeError) {
        let j=value.record
        try id(j.id);try id(j.parentBody);try id(j.childBody);try anchor(j.parentAnchor);try anchor(j.childAnchor)
        try byte(NativeWireTags.jointKind(j.manifold.kind));try count(j.manifold.orderedAxes.count)
        for axis in j.manifold.orderedAxes { try byte(NativeWireTags.axisKind(axis.kind));try vector(axis.direction);try scalar(axis.pitchMetersPerRadian) }
        try byte(NativeWireTags.authority(value.authority))
    }
    mutating func doubles(_ values:[Double]) throws(ExchangeError) { try count(values.count,record:false);for v in values { try scalar(v) } }
    mutating func state(_ value:KinematicState) throws(ExchangeError) {
        try integer(value.revision);try scalar(value.time);try doubles(value.q);try doubles(value.v);try doubles(value.acceleration)
        try count(value.prescribedAnchors.count)
        for a in value.prescribedAnchors { try id(a.frame);try scalar(a.time);try motion(a.motion) }
    }
    mutating func dimension(_ value:PhysicalDimension) throws(ExchangeError) {
        try byte(UInt8(bitPattern:value.length));try byte(UInt8(bitPattern:value.mass));try byte(UInt8(bitPattern:value.time));try byte(UInt8(bitPattern:value.angle))
        try byte(UInt8(bitPattern:value.electricCurrent));try byte(UInt8(bitPattern:value.temperature));try byte(UInt8(bitPattern:value.amount));try byte(UInt8(bitPattern:value.luminousIntensity))
    }
    mutating func feature(_ value:FeatureRequirement) throws(ExchangeError) {
        try text(value.feature);try byte(NativeWireTags.operation(value.operation));try byte(NativeWireTags.domain(value.domain));try byte(NativeWireTags.precision(value.precision));try byte(NativeWireTags.backend(value.backend));try byte(NativeWireTags.compilerTarget(value.target))
    }
    mutating func extensionRecord(_ value:MechanicalExtensionRecord) throws(ExchangeError) {
        try id(value.id);try text(value.schema);try count(value.references.count);for r in value.references { try id(r) }
        try count(value.parameters.count);for p in value.parameters { try text(p.name);try scalar(p.value);try dimension(p.dimension) }
    }
    mutating func document(_ value:NativeMechanicalDocument) throws(ExchangeError) {
        try byte(83);try byte(77);try byte(78);try byte(88);try integer(1);try byte(1)
        let d=value.descriptor
        try text(d.identity);try integer(d.revision);try count(d.bodies.count);for b in d.bodies { try body(b) }
        try count(d.joints.count);for j in d.joints { try joint(j) }
        try id(d.root);try byte(NativeWireTags.baseLayout(d.rootBase));try byte(NativeWireTags.authority(d.rootAuthority));try id(d.worldFrame);try state(d.initialState)
        try count(d.representationRequirements.count)
        for r in d.representationRequirements { try id(r.body);try count(r.geometry.count);for g in r.geometry { try byte(NativeWireTags.representationKind(g)) };try byte(NativeWireTags.inertiaRequirement(r.inertia)) }
        try count(d.features.count);for f in d.features { try feature(f) }
        try count(d.extensions.count);for e in d.extensions { try extensionRecord(e) }
        try count(value.assets.count)
        for a in value.assets {
            try text(a.key);try text(a.format);try provenance(a.provenance);try integer(UInt64(a.bytes.count))
            guard a.bytes.count <= work.policy.maximumWireBytes else { throw .resourceLimit(resource:.wireBytes,limit:work.policy.maximumWireBytes) }
            for b in a.bytes { try byte(b) }
        }
    }
}
