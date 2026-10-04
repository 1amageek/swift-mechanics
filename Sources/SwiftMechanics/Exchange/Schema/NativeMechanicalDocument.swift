public struct NativeMechanicalDocument: Equatable, Sendable {
    public let descriptor:MechanicalDescriptor
    public let assets:[NativeInlineAsset]
    public init(descriptor:MechanicalDescriptor,assets:[NativeInlineAsset]) { self.descriptor=descriptor;self.assets=assets }
}
