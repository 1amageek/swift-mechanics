public struct MJCFNativeExport: Sendable {
    public let bytes: [UInt8]
    public let loss: MJCFLoss
    public let originalSource: SourceProvenance
    internal init(bytes: [UInt8], loss: MJCFLoss, originalSource: SourceProvenance) { self.bytes = bytes; self.loss = loss; self.originalSource = originalSource }
}
