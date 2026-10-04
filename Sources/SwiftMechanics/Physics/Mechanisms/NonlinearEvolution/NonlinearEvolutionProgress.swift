internal final class NonlinearEvolutionProgress: Sendable {
    let accepted:RuntimeAcceptedState
    let steps:Int
    let rejects:Int
    let attempts:Int
    let work:NonlinearMechanismWorkReport
    let retry:Double?
    let error:Double?
    init(accepted:RuntimeAcceptedState,steps:Int = 0,rejects:Int = 0,attempts:Int = 0,work:NonlinearMechanismWorkReport = NonlinearMechanismWorkReport(),retry:Double? = nil,error:Double? = nil) {
        self.accepted=accepted;self.steps=steps;self.rejects=rejects;self.attempts=attempts;self.work=work;self.retry=retry;self.error=error
    }
    func report(adding attempt:NonlinearMechanismAttempt,unavailable:Bool = false) -> NonlinearMechanismWorkReport {
        NonlinearMechanismWorkReport(outer:work.outerArithmeticBoundCharged+attempt.work.outerArithmeticBoundCharged,
            supplier:work.supplierArithmeticCharged+attempt.work.supplierArithmeticCharged,calls:work.derivativeCalls+attempt.work.derivativeCalls,scalars:0,
            iterations:work.supplierIterationsCharged+attempt.work.supplierIterationsCharged,supplierScalars:max(work.peakSupplierScalars,attempt.work.peakSupplierScalars),
            unavailable:work.failedSupplierWorkUnavailable || attempt.work.failedSupplierWorkUnavailable || unavailable)
    }
}
