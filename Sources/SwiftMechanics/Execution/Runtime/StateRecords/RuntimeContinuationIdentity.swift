public struct RuntimeContinuationIdentity: Equatable, Sendable {
    public let build: String
    public let backend: String
    public let precision: String
    public init(build: String, backend: String, precision: String) throws(RuntimeFailure) {
        guard !build.isEmpty, !backend.isEmpty, precision == "float64" else { throw RuntimeFailure(.invalidInput, message: "Continuation requires explicit build/backend and float64 state precision.") }
        self.build = build; self.backend = backend; self.precision = precision
    }
}
