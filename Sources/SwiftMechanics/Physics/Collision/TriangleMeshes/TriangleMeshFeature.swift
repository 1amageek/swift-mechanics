public enum TriangleMeshFeature: Equatable, Sendable {
    case face(id: UInt64)
    case edge(firstVertex: Int, secondVertex: Int)
    case vertex(index: Int)
}
