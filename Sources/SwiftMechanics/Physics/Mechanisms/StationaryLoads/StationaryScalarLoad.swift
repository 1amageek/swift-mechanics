public struct StationaryScalarLoad: Equatable, Sendable {
    public let id:UInt64
    public let coordinateID:UInt64
    public let law:PolynomialSpringDamper
    public init(id:UInt64,coordinateID:UInt64,law:PolynomialSpringDamper) { self.id=id;self.coordinateID=coordinateID;self.law=law }
}
