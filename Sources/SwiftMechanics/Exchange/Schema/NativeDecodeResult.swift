public struct NativeDecodeResult: Sendable {
    public let document:NativeMechanicalDocument
    public let maximumComponentCorrection:Double
    public let correctedUnitRecords:Int
}
