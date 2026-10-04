public struct GranularNeighbor: Equatable, Sendable {
    public let bindingIndex: Int
    public let separation: Double
    internal init(bindingIndex: Int, separation: Double) { self.bindingIndex=bindingIndex; self.separation=separation }
}
