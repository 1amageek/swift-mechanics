internal struct IntegrationAttemptEvidence: Sendable {
    let work: IntegrationWorkReport
    let error: Double?
    let nextStep: Double?
    init(work: IntegrationWorkReport = IntegrationWorkReport(), error: Double? = nil, next: Double? = nil) {
        self.work = work; self.error = error; nextStep = next
    }
}
