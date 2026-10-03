import MechanicsCompiler
public enum ExchangeError: Error, Equatable, Sendable {
    case invalidPolicy, invalidInput, arithmeticOverflow, unsupportedVersion(UInt64), unsupportedUnits(UInt8)
    case malformedHeader, invalidUTF8(offset:Int), truncated(offset:Int), unknownTag(offset:Int), trailingBytes(offset:Int)
    case nonfiniteScalar(offset:Int), producerRecord(offset:Int), normalizationExceeded(value:Double,limit:Double)
    case duplicateIdentity, duplicateAsset, duplicateFeature, duplicateRequirement
    case unsupportedFeature, unsupportedExtension, unsupportedAssetFormat, unsupportedReference
    case missingAsset, staleAsset
    case resourceLimit(resource:ExchangeResource,limit:Int), cancelled
    case compilation(CompilationFailure)
}
internal func exchangeBuild<T>(at offset:Int,_ operation:() throws -> T) throws(ExchangeError) -> T {
    do { return try operation() } catch { throw .producerRecord(offset:offset) }
}
