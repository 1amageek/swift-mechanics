/// Raw complex scalar; numerical operations admit finite coordinates and amplitude explicitly.
public struct SpectrumComplex: Equatable, Sendable {
    public let real: Double
    public let imaginary: Double
    public init(real: Double, imaginary: Double) { self.real=real; self.imaginary=imaginary }
    public var amplitude: Double { ScalarMath.norm(real,imaginary) }
    internal var conjugate: Self { Self(real:real,imaginary:-imaginary) }
    internal var finite: Bool { real.isFinite && imaginary.isFinite && amplitude.isFinite }
    internal static let zero = Self(real:0,imaginary:0)
    internal static let one = Self(real:1,imaginary:0)
    internal static func + (a:Self,b:Self) -> Self { Self(real:a.real+b.real,imaginary:a.imaginary+b.imaginary) }
    internal static func - (a:Self,b:Self) -> Self { Self(real:a.real-b.real,imaginary:a.imaginary-b.imaginary) }
    internal static prefix func - (a:Self) -> Self { Self(real:-a.real,imaginary:-a.imaginary) }
    internal static func * (a:Self,b:Self) -> Self { Self(real:a.real*b.real-a.imaginary*b.imaginary,imaginary:a.real*b.imaginary+a.imaginary*b.real) }
    internal static func * (a:Self,b:Double) -> Self { Self(real:a.real*b,imaginary:a.imaginary*b) }
    internal static func / (a:Self,b:Double) -> Self { Self(real:a.real/b,imaginary:a.imaginary/b) }
    internal static func / (a:Self,b:Self) -> Self {
        // Smith division avoids squaring the divisor amplitude.
        if abs(b.real)>=abs(b.imaginary) {
            let r=b.imaginary/b.real,d=b.real+b.imaginary*r
            return Self(real:(a.real+a.imaginary*r)/d,imaginary:(a.imaginary-a.real*r)/d)
        }
        let r=b.real/b.imaginary,d=b.imaginary+b.real*r
        return Self(real:(a.real*r+a.imaginary)/d,imaginary:(a.imaginary*r-a.real)/d)
    }
    internal var squareRoot: Self {
        if real==0 && imaginary==0 { return .zero }
        let t=(amplitude/2+abs(real)/2).squareRoot()
        if real>=0 { return Self(real:t,imaginary:imaginary/(2*t)) }
        let y=imaginary<0 ? -t : t
        return Self(real:imaginary/(2*y),imaginary:y)
    }
}
