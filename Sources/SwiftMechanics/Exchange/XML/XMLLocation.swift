public struct XMLLocation: Equatable, Sendable {
    public let byteOffset: Int
    public let line: Int
    public let byteColumn: Int
    public init(byteOffset: Int = 0, line: Int = 1, byteColumn: Int = 1) {
        self.byteOffset = byteOffset; self.line = line; self.byteColumn = byteColumn
    }
}
