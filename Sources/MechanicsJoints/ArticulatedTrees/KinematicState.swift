public struct KinematicState: Equatable, Sendable {
    public let revision: UInt64
    public let time: Double
    public let q: [Double]
    public let v: [Double]
    public let acceleration: [Double]
    public let prescribedAnchors: [PrescribedAnchorState]

    public init(revision: UInt64, time: Double, q: [Double], v: [Double], acceleration: [Double],
                prescribedAnchors: [PrescribedAnchorState] = []) throws(JointError) {
        guard time.isFinite, q.allSatisfy({ $0.isFinite }), v.allSatisfy({ $0.isFinite }),
              acceleration.allSatisfy({ $0.isFinite }) else { throw .nonFiniteState }
        self.revision = revision; self.time = time; self.q = q; self.v = v
        self.acceleration = acceleration; self.prescribedAnchors = prescribedAnchors
    }
}
