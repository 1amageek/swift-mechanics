public enum PrescribedTrajectory: Sendable {
    case quadratic(AnalyticPrescribedMotion)
    case harmonic(HarmonicPrescribedMotion)
    case piecewise(PiecewisePrescribedMotion)
    public var frame:EntityID { switch self { case .quadratic(let m):m.frame;case .harmonic(let m):m.frame;case .piecewise(let m):m.frame } }
    public var parentFrame:EntityID { switch self { case .quadratic(let m):m.parentFrame;case .harmonic(let m):m.parentFrame;case .piecewise(let m):m.parentFrame } }
    public var referenceTime:Double { switch self { case .quadratic(let m):m.referenceTime;case .harmonic(let m):m.referenceTime;case .piecewise(let m):m.referenceTime } }
    public var initialPose:RigidTransform { switch self { case .quadratic(let m):m.initialPose;case .harmonic(let m):m.initialPose;case .piecewise(let m):m.initialPose } }
    public var rotationAxis:Vector3 { switch self { case .quadratic(let m):m.rotationAxis;case .harmonic(let m):m.rotationAxis;case .piecewise(let m):m.rotationAxis } }
    public var minimumTime:Double { switch self { case .quadratic(let m):m.minimumTime;case .harmonic(let m):m.minimumTime;case .piecewise(let m):m.minimumTime } }
    public var maximumTime:Double { switch self { case .quadratic(let m):m.maximumTime;case .harmonic(let m):m.maximumTime;case .piecewise(let m):m.maximumTime } }
    public var segmentCount:Int { if case .piecewise(let m)=self { return m.segments.count };return 0 }
}
