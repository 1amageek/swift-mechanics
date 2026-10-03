public struct RuntimeFailure: Error, Sendable {
    public let code: RuntimeFailureCode
    public let contributor: String?
    public let message: String
    public let lastAccepted: RuntimeAcceptedState?
    public init(_ code: RuntimeFailureCode, contributor: String? = nil, message: String, lastAccepted: RuntimeAcceptedState? = nil) {
        self.code = code; self.contributor = contributor; self.message = message; self.lastAccepted = lastAccepted
    }
    public func retaining(_ accepted: RuntimeAcceptedState) -> RuntimeFailure {
        RuntimeFailure(code, contributor: contributor, message: message, lastAccepted: accepted)
    }
}
