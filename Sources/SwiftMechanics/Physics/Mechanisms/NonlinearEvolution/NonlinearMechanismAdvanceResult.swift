public struct NonlinearMechanismAdvanceResult: Sendable {
    public let requestedTime: Double
    public let accepted: RuntimeAcceptedState
    public let acceptedSteps: Int
    public let rejectedTrials: Int
    public let work: NonlinearMechanismWorkReport
    public let lastNormalizedError: Double?
    public var reachedRequestedTime:Bool { accepted.checkpoint.physical.time == requestedTime }
    internal init(requested:Double,accepted:RuntimeAcceptedState,steps:Int,rejects:Int,work:NonlinearMechanismWorkReport,error:Double?) {
        requestedTime=requested;self.accepted=accepted;acceptedSteps=steps;rejectedTrials=rejects;self.work=work;lastNormalizedError=error
    }
}
