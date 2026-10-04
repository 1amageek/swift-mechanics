import SwiftMechanics

/// Independent scalar determinant calculus, unrelated to the spectral implementation.
enum ComplexFixtureMath {
    static func add(_ a:SpectrumComplex,_ b:SpectrumComplex) -> SpectrumComplex { SpectrumComplex(real:a.real+b.real,imaginary:a.imaginary+b.imaginary) }
    static func scale(_ a:SpectrumComplex,_ b:Double) -> SpectrumComplex { SpectrumComplex(real:a.real*b,imaginary:a.imaginary*b) }
    static func multiply(_ a:SpectrumComplex,_ b:SpectrumComplex) -> SpectrumComplex { SpectrumComplex(real:a.real*b.real-a.imaginary*b.imaginary,imaginary:a.real*b.imaginary+a.imaginary*b.real) }
    static func divide(_ a:SpectrumComplex,_ b:SpectrumComplex) -> SpectrumComplex {
        let denominator=b.real*b.real+b.imaginary*b.imaginary
        return SpectrumComplex(real:(a.real*b.real+a.imaginary*b.imaginary)/denominator,imaginary:(a.imaginary*b.real-a.real*b.imaginary)/denominator)
    }
    static func distance(_ a:SpectrumComplex,_ b:SpectrumComplex) -> Double { ((a.real-b.real)*(a.real-b.real)+(a.imaginary-b.imaginary)*(a.imaginary-b.imaginary)).squareRoot() }
    static func polynomial(_ z:SpectrumComplex,_ c:Double) -> SpectrumComplex {
        let z2=multiply(z,z),first=add(add(z2,z),SpectrumComplex(real:2,imaginary:0)),second=add(add(z2,scale(z,2)),SpectrumComplex(real:8,imaginary:0))
        return add(multiply(first,second),scale(z2,-c*c))
    }
    static func derivative(_ z:SpectrumComplex,_ c:Double) -> SpectrumComplex {
        let z2=multiply(z,z),first=add(add(z2,z),SpectrumComplex(real:2,imaginary:0)),second=add(add(z2,scale(z,2)),SpectrumComplex(real:8,imaginary:0))
        return add(add(multiply(add(scale(z,2),SpectrumComplex(real:1,imaginary:0)),second),multiply(first,add(scale(z,2),SpectrumComplex(real:2,imaginary:0)))),scale(z,-2*c*c))
    }
    static func root(_ start:SpectrumComplex,coupling:Double) -> SpectrumComplex {
        var z=start
        for _ in 0..<12 { z=add(z,scale(divide(polynomial(z,coupling),derivative(z,coupling)),-1)) }
        return z
    }
}
