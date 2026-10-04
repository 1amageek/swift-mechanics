internal struct StationaryCanonicalBytes {
    var bytes:[UInt8]=[]
    let maximum:Int
    mutating func word(_ value:UInt64) throws(StationaryLoadError) {
        guard bytes.count <= maximum,maximum-bytes.count >= 8 else { throw .capacity }
        for shift in stride(from:0,to:64,by:8) { bytes.append(UInt8(truncatingIfNeeded:value >> shift)) }
    }
    mutating func scalar(_ value:Double) throws(StationaryLoadError) { guard value.isFinite else { throw .invalidInput };try word(value.bitPattern) }
    mutating func text(_ value:String) throws(StationaryLoadError) {
        var count=0
        for _ in value.utf8 { guard count < maximum else { throw .capacity };count+=1 }
        try word(UInt64(count));guard bytes.count <= maximum, count <= maximum-bytes.count else { throw .capacity }
        bytes.append(contentsOf:value.utf8)
    }
    mutating func vector(_ value:Vector3) throws(StationaryLoadError) { try scalar(value.x);try scalar(value.y);try scalar(value.z) }
    mutating func matrix(_ value:Matrix3) throws(StationaryLoadError) { for x in [value.m00,value.m01,value.m02,value.m10,value.m11,value.m12,value.m20,value.m21,value.m22] { try scalar(x) } }
    mutating func pose(_ value:RigidTransform) throws(StationaryLoadError) { try vector(value.translation);for x in [value.rotation.w,value.rotation.x,value.rotation.y,value.rotation.z] { try scalar(x) } }
}
