@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class GeometricAssemblyAttempt: Sendable {
    let result:ManifoldAssemblyResult?
    let failure:ManifoldProjectionFailure?
    let work:NumericalWork
    let before:NumericalWork
    init(result:ManifoldAssemblyResult?,failure:ManifoldProjectionFailure?,work:NumericalWork,before:NumericalWork) {
        self.result=result;self.failure=failure;self.work=work;self.before=before
    }
}
