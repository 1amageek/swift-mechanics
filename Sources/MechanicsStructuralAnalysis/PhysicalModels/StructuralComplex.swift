import CMechanicsMath
public struct StructuralComplex: Equatable, Sendable {
    public let real: Double
    public let imaginary: Double
    public init(real: Double, imaginary: Double) throws(StructuralError) {
        guard real.isFinite,imaginary.isFinite,sm_hypot(real,imaginary).isFinite else { throw .nonFiniteResult }
        self.real=real;self.imaginary=imaginary
    }
    public var amplitude: Double { sm_hypot(real,imaginary) }
    /// Convention Re(z exp(i omega t)); phase is unavailable for exact zero amplitude.
    public var phaseRadians: Double? { real==0 && imaginary==0 ? nil : sm_atan2(imaginary,real) }
}
