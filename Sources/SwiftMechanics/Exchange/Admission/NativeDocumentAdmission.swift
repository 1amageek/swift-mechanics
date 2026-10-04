internal enum NativeDocumentAdmission {
    static func validate(_ document:NativeMechanicalDocument,work:inout ExchangeWork) throws(ExchangeError) {
        try catalog(work.policy.extensionSchemas,work:&work);try catalog(work.policy.featureNames,work:&work);try catalog(work.policy.assetFormats,work:&work)
        let d=document.descriptor
        let n=try ExchangeWork.sum(1,ExchangeWork.sum(ExchangeWork.product(d.bodies.count,2),ExchangeWork.sum(ExchangeWork.product(d.joints.count,3),d.extensions.count)))
        guard n <= work.policy.maximumRecords else { throw .resourceLimit(resource:.records,limit:work.policy.maximumRecords) }
        try work.allocate(ExchangeWork.product(n,MemoryLayout<EntityID>.stride))
        var ids:[EntityID]=[];ids.reserveCapacity(n)
        try unique(d.worldFrame,ids:&ids,work:&work)
        for b in d.bodies { try unique(b.id,ids:&ids,work:&work);try unique(b.frame,ids:&ids,work:&work) }
        for j in d.joints { try unique(j.record.id,ids:&ids,work:&work);try unique(j.record.parentAnchor.frame,ids:&ids,work:&work);try unique(j.record.childAnchor.frame,ids:&ids,work:&work) }
        for e in d.extensions {
            try unique(e.id,ids:&ids,work:&work)
            guard try contains(e.schema,in:work.policy.extensionSchemas,work:&work) else { throw .unsupportedExtension }
        }
        for i in d.features.indices {
            guard try contains(d.features[i].feature,in:work.policy.featureNames,work:&work) else { throw .unsupportedFeature }
            for j in 0..<i { if try same(d.features[i].feature,d.features[j].feature,work:&work) { throw .duplicateFeature } }
        }
        for i in d.representationRequirements.indices {
            for j in 0..<i { if try same(d.representationRequirements[i].body,d.representationRequirements[j].body,work:&work) { throw .duplicateRequirement } }
            let kinds=d.representationRequirements[i].geometry
            for j in kinds.indices { for k in 0..<j { try work.charge(1);if kinds[j] == kinds[k] { throw .duplicateRequirement } } }
        }
        for i in document.assets.indices {
            let a=document.assets[i];try assetKey(a.key,work:&work)
            guard try contains(a.format,in:work.policy.assetFormats,work:&work) else { throw .unsupportedAssetFormat }
            for j in 0..<i { if try same(a.key,document.assets[j].key,work:&work) { throw .duplicateAsset } }
        }
        for b in d.bodies {
            try association(b.representations.geometricShape,assets:document.assets,work:&work)
            try association(b.representations.displayGeometry,assets:document.assets,work:&work)
            try association(b.representations.collisionGeometry,assets:document.assets,work:&work)
        }
        try work.checkCancellation()
    }
    static func catalog(_ values:[String],work:inout ExchangeWork) throws(ExchangeError) {
        guard values.count <= work.policy.maximumRecords else { throw .invalidPolicy }
        var total=0
        for i in values.indices {
            let n=try length(values[i],work:&work);guard n > 0 else { throw .invalidPolicy }
            total=try ExchangeWork.sum(total,n)
            guard total <= work.policy.maximumMetadataBytes else { throw .resourceLimit(resource:.metadataBytes,limit:work.policy.maximumMetadataBytes) }
            for j in 0..<i { if try same(values[i],values[j],work:&work) { throw .invalidPolicy } }
        }
    }
    static func length(_ value:String,work:inout ExchangeWork) throws(ExchangeError) -> Int {
        var n=0
        for _ in value.utf8 { try work.charge(1);n=try ExchangeWork.sum(n,1);guard n <= work.policy.maximumStringBytes else { throw .resourceLimit(resource:.stringBytes,limit:work.policy.maximumStringBytes) } }
        return n
    }
    static func same(_ a:String,_ b:String,work:inout ExchangeWork) throws(ExchangeError) -> Bool {
        let x=try length(a,work:&work),y=try length(b,work:&work);try work.charge(ExchangeWork.sum(1,ExchangeWork.sum(x,y)));return a == b
    }
    static func same(_ a:EntityID,_ b:EntityID,work:inout ExchangeWork) throws(ExchangeError) -> Bool {
        try work.charge(1);if a.kind != b.kind { return false };return try same(a.key,b.key,work:&work)
    }
    static func unique(_ id:EntityID,ids:inout [EntityID],work:inout ExchangeWork) throws(ExchangeError) {
        for old in ids { if try same(id,old,work:&work) { throw .duplicateIdentity } };ids.append(id)
    }
    static func contains(_ word:String,in values:[String],work:inout ExchangeWork) throws(ExchangeError) -> Bool {
        for value in values { if try same(word,value,work:&work) { return true } };return false
    }
    static func assetKey(_ key:String,work:inout ExchangeWork) throws(ExchangeError) {
        guard !key.isEmpty else { throw .unsupportedReference }
        for byte in key.utf8 {
            try work.charge(1)
            guard (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || byte == 45 || byte == 95 else { throw .unsupportedReference }
        }
    }
    static func association(_ representation:GeometryRepresentation?,assets:[NativeInlineAsset],work:inout ExchangeWork) throws(ExchangeError) {
        guard let r=representation else { return };try assetKey(r.assetKey,work:&work)
        for asset in assets {
            if try same(r.assetKey,asset.key,work:&work) {
                guard try same(r.provenance.source,asset.provenance.source,work:&work),r.provenance.revision == asset.provenance.revision else { throw .staleAsset };return
            }
        }
        throw .missingAsset
    }
}
