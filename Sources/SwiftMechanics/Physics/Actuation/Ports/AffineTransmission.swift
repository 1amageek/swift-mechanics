public struct AffineTransmission: Equatable, Sendable {
    public let model:ModelStamp,frame:EntityID
    public let outputCoordinate:ScalarCoordinateKind,inputCoordinates:[ScalarCoordinateKind]
    public let gradient:[Double],prescribedRate:Double
    public init(model:ModelStamp,frame:EntityID,outputCoordinate:ScalarCoordinateKind,inputCoordinates:[ScalarCoordinateKind],gradient:[Double],prescribedRate:Double,
                work:inout ActuationWork) throws(ActuationError) {
        guard frame.kind == .frame,!model.identity.isEmpty,gradient.count == inputCoordinates.count,!gradient.isEmpty else { throw .invalidInput }
        try work.reserve(scalars:gradient.count);try work.metadata(model.identity);try work.metadata(frame.key)
        var nonzero=false
        for g in gradient { try work.charge(1);guard g.isFinite else { throw .invalidInput };if g != 0 { nonzero=true } }
        guard nonzero,prescribedRate.isFinite else { throw .outsideDomain }
        self.model=model;self.frame=frame;self.outputCoordinate=outputCoordinate;self.inputCoordinates=inputCoordinates;self.gradient=gradient;self.prescribedRate=prescribedRate
    }
}
