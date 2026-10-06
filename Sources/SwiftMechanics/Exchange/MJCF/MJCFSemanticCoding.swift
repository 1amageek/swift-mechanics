public protocol MJCFSemanticCoding: Sendable {
    func importModel(bytes: [UInt8], context: MJCFImportContext, work: inout MJCFWork,
                     xmlWork: inout XMLWork, actuationWork: inout ActuationWork,
                     numericalWork: inout NumericalWork) throws(MJCFError) -> MJCFImportedModel
    func exportModel(_ model: MJCFImportedModel, expectedStamp: ModelStamp, work: inout MJCFWork,
                     xmlWork: inout XMLWork, actuationWork: inout ActuationWork,
                     numericalWork: inout NumericalWork) throws(MJCFError) -> [UInt8]
    func exportNativeStructure(_ model: MJCFImportedModel, expectedStamp: ModelStamp, work: inout MJCFWork,
                               exchangeWork: inout ExchangeWork) throws(MJCFError) -> MJCFNativeExport
}
