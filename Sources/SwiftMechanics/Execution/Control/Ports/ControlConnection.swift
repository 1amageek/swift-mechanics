public struct ControlConnection: Sendable {
    public let source: Int
    public let destination: Int
    public let dimension: PhysicalDimension
    public init(source:Int,destination:Int,dimension:PhysicalDimension) {
        self.source=source;self.destination=destination;self.dimension=dimension
    }
}
