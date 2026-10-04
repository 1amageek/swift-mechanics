public protocol NativeModelCoding: Sendable {
    func encode(document:NativeMechanicalDocument,work:inout ExchangeWork) throws(ExchangeError) -> [UInt8]
    func decode(bytes:[UInt8],work:inout ExchangeWork) throws(ExchangeError) -> NativeDecodeResult
}
