struct ImplicitAttemptState: Sendable {
    var endpoint: ImplicitEulerEndpoint?
    var cause: ImplicitMethodCause?
    var work: NumericalWork
    var unavailable = false
}
