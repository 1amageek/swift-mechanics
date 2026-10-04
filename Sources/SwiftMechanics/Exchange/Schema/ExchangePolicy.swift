public struct ExchangePolicy: Sendable {
    public let maximumWireBytes:Int, maximumRecords:Int, maximumArrayElements:Int
    public let maximumStringBytes:Int, maximumMetadataBytes:Int, maximumAllocationBytes:Int, maximumOperations:Int
    public let maximumUnitComponentCorrection:Double
    public let inertiaPolicy:InertiaValidationPolicy
    public let extensionSchemas:[String], featureNames:[String], assetFormats:[String]
    public init(maximumWireBytes:Int, maximumRecords:Int, maximumArrayElements:Int, maximumStringBytes:Int,
                maximumMetadataBytes:Int, maximumAllocationBytes:Int, maximumOperations:Int,
                maximumUnitComponentCorrection:Double, inertiaPolicy:InertiaValidationPolicy,
                extensionSchemas:[String], featureNames:[String], assetFormats:[String]) throws(ExchangeError) {
        guard maximumWireBytes >= 0, maximumRecords >= 0, maximumArrayElements >= 0, maximumStringBytes >= 0,
              maximumMetadataBytes >= 0, maximumAllocationBytes >= 0, maximumOperations >= 0,
              maximumUnitComponentCorrection.isFinite, maximumUnitComponentCorrection >= 0, maximumUnitComponentCorrection < 1,
              extensionSchemas.count <= maximumRecords,featureNames.count <= maximumRecords,assetFormats.count <= maximumRecords else { throw .invalidPolicy }
        self.maximumWireBytes=maximumWireBytes; self.maximumRecords=maximumRecords; self.maximumArrayElements=maximumArrayElements
        self.maximumStringBytes=maximumStringBytes; self.maximumMetadataBytes=maximumMetadataBytes
        self.maximumAllocationBytes=maximumAllocationBytes; self.maximumOperations=maximumOperations
        self.maximumUnitComponentCorrection=maximumUnitComponentCorrection; self.inertiaPolicy=inertiaPolicy
        self.extensionSchemas=extensionSchemas; self.featureNames=featureNames; self.assetFormats=assetFormats
    }
}
