public struct ImplicitEulerStepResult: Sendable {
    public let accepted: RuntimeAcceptedState
    public let endpoint: ImplicitEulerEndpoint
}
