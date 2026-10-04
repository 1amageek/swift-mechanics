public struct PatchWorkspace: Sendable {
    // One owned fixed cut buffer is reused for every cell; no inner-loop arrays.
    internal var cut=[PatchVertex](repeating:.zero,count:4)
    public init() {}
}
