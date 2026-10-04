public struct StationaryLoadProgram: Equatable, Sendable {
    public let id:UInt64
    public let revision:UInt64
    public let gravity:AffineGravity?
    public let terms:[StationaryScalarLoad]
    public init(id:UInt64,revision:UInt64,gravity:AffineGravity?,terms:[StationaryScalarLoad]) { self.id=id;self.revision=revision;self.gravity=gravity;self.terms=terms }
}
