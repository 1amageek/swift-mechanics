public struct ImplicitEulerPolicy: Sendable {
    public let scales: [ODEErrorScale]
    public let nonlinear: NonlinearPolicy<Double>
    public init(scales: [ODEErrorScale], nonlinear: NonlinearPolicy<Double>) throws(ImplicitMethodCause) {
        guard !scales.isEmpty else { throw .invalidInput }
        self.scales = scales; self.nonlinear = nonlinear
    }
}
