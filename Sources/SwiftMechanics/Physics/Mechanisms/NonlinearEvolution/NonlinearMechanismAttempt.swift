internal struct NonlinearMechanismAttempt: Sendable {
    let work:NonlinearMechanismWorkReport
    let error:Double?
    let nextStep:Double?
    init(work:NonlinearMechanismWorkReport = NonlinearMechanismWorkReport(),error:Double? = nil,next:Double? = nil) {
        self.work=work;self.error=error;nextStep=next
    }
}
