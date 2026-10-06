public struct URDFFailure: Error, Sendable {
    public enum Reason: Sendable {
        case invalidPolicy, arithmeticOverflow, cancelled
        case limit(String, Int), missing(String), invalid(String), duplicate(String), unsupported(String)
        case xml(XMLFailure), compilation(CompilationFailure), core(CoreError), model(ModelError)
        case joint(JointError), collision(CollisionError), dynamics(DynamicsError), unexpectedProducer
    }
    public let reason: Reason
    public let location: XMLLocation
    public init(_ reason: Reason, at location: XMLLocation = XMLLocation()) {
        self.reason = reason; self.location = location
    }
}
