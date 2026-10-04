public struct NonlinearMechanismFailure: Error, Sendable {
    public let cause: RuntimeFailure
    public let lastAccepted: RuntimeAcceptedState
    public let work: NonlinearMechanismWorkReport
    public let acceptedSteps: Int
    public let rejectedTrials: Int
    internal init(cause:RuntimeFailure,accepted:RuntimeAcceptedState,work:NonlinearMechanismWorkReport,steps:Int,rejects:Int) {
        self.cause=cause;lastAccepted=accepted;self.work=work;acceptedSteps=steps;rejectedTrials=rejects
    }
}
