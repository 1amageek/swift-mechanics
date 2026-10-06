public struct GeneralDampedSpectrumFailure: Error, Sendable {
    public let cause: GeneralDampedSpectrumCause
    public let work: NumericalWork
    public let failedSupplierWorkUnavailable: Bool
    internal init(cause:GeneralDampedSpectrumCause,work:NumericalWork,unavailable:Bool) {
        self.cause=cause;self.work=work;failedSupplierWorkUnavailable=unavailable
    }
}
