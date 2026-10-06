public struct HarmonicGravityLaw: Sendable, Equatable {
    public let frame: EntityID
    public let constantAcceleration: Vector3
    public let cosineAcceleration: Vector3
    public let sineAcceleration: Vector3
    public let constantGradient: Matrix3
    public let cosineGradient: Matrix3
    public let sineGradient: Matrix3
    public let angularFrequency: Double
    public let timeOrigin: Double
    public let phase: Double
    public init(frame: EntityID, constantAcceleration: Vector3, cosineAcceleration: Vector3, sineAcceleration: Vector3,
                constantGradient: Matrix3, cosineGradient: Matrix3, sineGradient: Matrix3,
                angularFrequency: Double, timeOrigin: Double, phase: Double) throws(LoadError) {
        guard frame.kind == .frame, angularFrequency.isFinite, angularFrequency >= 0,
              timeOrigin.isFinite, phase.isFinite else { throw .invalidInput }
        for matrix in [constantGradient,cosineGradient,sineGradient] {
            guard matrix.m01 == matrix.m10, matrix.m02 == matrix.m20, matrix.m12 == matrix.m21 else { throw .invalidPassiveLaw }
        }
        self.frame = frame; self.constantAcceleration = constantAcceleration; self.cosineAcceleration = cosineAcceleration
        self.sineAcceleration = sineAcceleration; self.constantGradient = constantGradient
        self.cosineGradient = cosineGradient; self.sineGradient = sineGradient
        self.angularFrequency = angularFrequency; self.timeOrigin = timeOrigin; self.phase = phase
    }
}
