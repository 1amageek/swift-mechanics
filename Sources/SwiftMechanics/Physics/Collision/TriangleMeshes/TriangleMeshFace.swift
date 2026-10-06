public struct TriangleMeshFace: Equatable, Sendable {
    public let id: UInt64
    public let a: Int
    public let b: Int
    public let c: Int

    public init(id: UInt64, a: Int, b: Int, c: Int) { self.id = id; self.a = a; self.b = b; self.c = c }
}
