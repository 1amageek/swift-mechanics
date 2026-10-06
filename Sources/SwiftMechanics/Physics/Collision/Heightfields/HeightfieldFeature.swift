public enum HeightfieldFeature: Equatable, Sendable {
    case vertex(index: Int)
    case edge(first: Int, second: Int)
    case face
}
