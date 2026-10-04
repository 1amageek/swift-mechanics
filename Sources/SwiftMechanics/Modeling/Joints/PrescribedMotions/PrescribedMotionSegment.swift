public struct PrescribedMotionSegment: Sendable {
    public let startTime:Double
    public let endTime:Double
    public let start:PrescribedMotionJet
    public let end:PrescribedMotionJet
    public init(startTime:Double,endTime:Double,start:PrescribedMotionJet,end:PrescribedMotionJet) throws(PrescribedMotionError) {
        let duration=endTime-startTime,inverse=1/duration
        guard startTime.isFinite,endTime.isFinite,startTime < endTime,duration.isFinite,
              inverse.isFinite,(inverse*inverse).isFinite else { throw .invalidInput }
        self.startTime=startTime;self.endTime=endTime;self.start=start;self.end=end
    }
}
